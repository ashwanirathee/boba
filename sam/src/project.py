import asyncio
import logging
import os
import queue
import sys
import tempfile
import threading
import platform
import termios
import wave
from contextlib import contextmanager
from pathlib import Path

import numpy as np
import sounddevice as sd
from dotenv import load_dotenv
from livekit.agents import cli
from mlx_audio.stt.utils import load_model as load_stt
from mlx_audio.tts.utils import load_model as load_tts
import requests
import re

import traceback
from kittentts import KittenTTS
from pynput import keyboard as pynput_keyboard

logger = logging.getLogger(__name__)

load_dotenv()

MLX_LOCK = asyncio.Lock()

class Project:
    RECORD_HOTKEY = "9"

    @contextmanager
    def suppress_terminal_echo(self):
        stream = sys.stdin
        if not hasattr(stream, "fileno") or not stream.isatty():
            yield
            return

        fd = stream.fileno()
        original_attrs = termios.tcgetattr(fd)
        updated_attrs = termios.tcgetattr(fd)
        updated_attrs[3] &= ~termios.ECHO

        try:
            termios.tcsetattr(fd, termios.TCSANOW, updated_attrs)
            yield
        finally:
            termios.tcsetattr(fd, termios.TCSANOW, original_attrs)

    def keyboard_hotkeys_available(self) -> bool:
        if platform.system() != "Darwin":
            return True

        try:
            import HIServices
            return bool(HIServices.AXIsProcessTrusted())
        except Exception:
            # If we cannot verify trust status, keep hotkeys enabled and let
            # pynput attempt to start normally.
            return True

    def wait_for_hotkey(self) -> str:
        command_ready = threading.Event()
        command = {"value": ""}

        def on_press(k):
            try:
                if hasattr(k, "char") and k.char:
                    if k.char.lower() == self.RECORD_HOTKEY and not command_ready.is_set():
                        command["value"] = self.RECORD_HOTKEY
                        command_ready.set()
                        return False

                if hasattr(k, "char") and k.char:
                    if k.char.lower() == "q" and not command_ready.is_set():
                        command["value"] = "q"
                        command_ready.set()
                        return False
            except Exception:
                pass

        listener = pynput_keyboard.Listener(on_press=on_press)
        with self.suppress_terminal_echo():
            listener.start()
            command_ready.wait()
            listener.stop()
            listener.join()
        return command["value"]

    def __init__(self, args=None):
        self.args = args
        self.hotkeys_enabled = self.keyboard_hotkeys_available()

        # Load introduction text from file
        intro_path = Path(__file__).parent.parent / "data" / "introduction_text.txt"
        try:
            with open(intro_path, "r", encoding="utf-8") as f:
                self.introduction_text = f.read().strip()
        except Exception:
            self.introduction_text = "Hello, I am your voice assistant. How can I help you today?"

        self.stt_model = (
            args.stt_model
            or os.getenv("LOCAL_STT_ID")
            or "mlx-community/parakeet-tdt-0.6b-v3"
        )

        self.tts_model = (
            args.tts_model
            or os.getenv("LOCAL_TTS_ID")
            or "mlx-community/Kokoro-82M-bf16"
        )

        self.local_tts = None
        self.tts_voice = None
        print(f"Using TTS model: {self.tts_model}")
        if self.tts_model and "kitten" in self.tts_model.lower():
            self.tts_voice = (self.args.tts_voice or os.getenv("LOCAL_TTS_VOICE") or "Luna")
            self.local_tts = KittenTTS(self.tts_model)
        elif self.tts_model and "Kokoro" in self.tts_model.lower():
            self.tts_voice = (self.args.tts_voice or os.getenv("LOCAL_TTS_VOICE") or "af_heart")
            self.local_tts = load_tts(self.tts_model)
        else:
            self.tts_voice = "af_heart"
            self.local_tts = load_tts(self.tts_model)

        print(f"tts_voice: {self.local_tts}")

        self.llm_model = (
            args.llm_model
            or os.getenv("LOCAL_LLM_ID")
            or "qwen2.5:latest"
        )

        self.local_stt = load_stt(self.stt_model)

        self.llm_mode = (os.getenv("OLLAMA_MODE") or "local")
        if self.llm_mode == "cloud":
            from ollama import Client

            self.ollama_client = Client(
                host="https://ollama.com",
                headers={"Authorization": "Bearer " + os.environ.get("OLLAMA_API_KEY")},
            )
        else:
            self.ollama_base_url = (
                args.ollama_base_url
                or os.getenv("OLLAMA_BASE_URL")
                or "http://127.0.0.1:11434"
            )

    async def run(self):
        import time
        logging.basicConfig(level=logging.INFO)

        logger.info("Voice assistant")
        if self.hotkeys_enabled:
            logger.info(f"Hold {self.RECORD_HOTKEY} to record and release to stop")
            logger.info("Press q to quit")
        else:
            logger.warning(
                "Global hotkeys are disabled because macOS Accessibility access "
                "is not enabled for this app."
            )
            logger.warning(
                "Enable it in System Settings > Privacy & Security > "
                "Accessibility for your terminal or IDE, then restart."
            )
            logger.info("Press 1 then Enter to start recording")
            logger.info("Press 2 then Enter to stop recording")
            logger.info("Press q then Enter to quit")

        audio_reply = await self.synthesize(self.introduction_text)
        try:
            await asyncio.to_thread(self.play_audio, audio_reply, 24000)
        except Exception as e:
            logger.info(f"Error during audio playback: {e}")
                
        while True:
            if self.hotkeys_enabled:
                logger.info(f"Hold {self.RECORD_HOTKEY} to record, or press q to quit.")
                cmd = await asyncio.to_thread(self.wait_for_hotkey)
            else:
                logger.info("Press 1 then Enter to record, or q then Enter to quit.")
                cmd = input("\nCommand: ").strip().lower()

            if cmd == "q":
                logger.info("Bye.")
                break

            if cmd == self.RECORD_HOTKEY:
                t0 = time.monotonic()
                audio = await asyncio.to_thread(
                    self.record_with_keyboard, 16000, 1, self.RECORD_HOTKEY
                )
                t1 = time.monotonic()
                logger.info(f"[Timing] Recording (keyboard) took {t1 - t0:.2f} seconds.")
            elif cmd == "1":
                t0 = time.monotonic()
                audio = await asyncio.to_thread(self.record_until_stop, 16000, 1)
                t1 = time.monotonic()
                logger.info(f"[Timing] Recording took {t1 - t0:.2f} seconds.")
            else:
                if self.hotkeys_enabled:
                    logger.info(f"Invalid command. Hold {self.RECORD_HOTKEY} or press q.")
                else:
                    logger.info("Invalid command. Press 1 or q.")
                continue

            if len(audio) == 0:
                logger.info("No audio captured.")
                continue

            logger.info("Transcribing...")
            t2 = time.monotonic()
            text = await self.transcribe(audio)
            t3 = time.monotonic()
            logger.info(f"[Timing] Transcription took {t3 - t2:.2f} seconds.")
            if not text:
                logger.info("No speech detected.")
                continue

            logger.info(f"You: {text}")

            logger.info("Thinking...")
            t4 = time.monotonic()
            reply = await self.ask_ollama(text)
            t5 = time.monotonic()
            logger.info(f"[Timing] LLM response took {t5 - t4:.2f} seconds.")
            logger.info(f"Assistant: {reply}")

            logger.info("Speaking...")
            t6 = time.monotonic()
            audio_reply = await self.synthesize(reply)
            t7 = time.monotonic()
            logger.info(f"[Timing] TTS synthesis took {t7 - t6:.2f} seconds.")
            try:
                await asyncio.to_thread(self.play_audio, audio_reply, 24000)
            except Exception as e:
                logger.info(f"Error during audio playback: {e}")

    def record_until_stop(
        self, sample_rate: int = 16000, channels: int = 1
    ) -> np.ndarray:
        q: queue.Queue[np.ndarray] = queue.Queue()
        stop_event = threading.Event()
        chunks: list[np.ndarray] = []

        def callback(indata, frames, time, status):
            if status:
                logger.info(status, file=sys.stderr)
            q.put(indata.copy())

        def wait_for_stop():
            while True:
                cmd = input().strip()
                if cmd == "2":
                    stop_event.set()
                    break

        logger.info("Recording... press 2 then Enter to stop.")
        threading.Thread(target=wait_for_stop, daemon=True).start()

        with sd.InputStream(
            samplerate=sample_rate,
            channels=channels,
            dtype="int16",
            callback=callback,
            blocksize=1024,
        ):
            while not stop_event.is_set():
                try:
                    chunk = q.get(timeout=0.1)
                    chunks.append(chunk)
                except queue.Empty:
                    pass

        if not chunks:
            return np.zeros((0,), dtype=np.int16)

        audio = np.concatenate(chunks, axis=0)
        if channels == 1:
            audio = audio[:, 0]
        return audio.astype(np.int16)

    def record_with_keyboard(
        self, sample_rate: int = 16000, channels: int = 1, trigger_char: str = "9"
    ) -> np.ndarray:
        q: queue.Queue[np.ndarray] = queue.Queue()
        stop_event = threading.Event()
        chunks: list[np.ndarray] = []

        def callback(indata, frames, time, status):
            if status:
                logger.info(status)
            q.put(indata.copy())

        def matches_trigger(k) -> bool:
            return bool(getattr(k, "char", None)) and k.char.lower() == trigger_char.lower()

        def on_release(k):
            if matches_trigger(k):
                stop_event.set()
                return False
            return None

        listener = pynput_keyboard.Listener(on_release=on_release)

        with self.suppress_terminal_echo():
            listener.start()

            try:
                with sd.InputStream(
                    samplerate=sample_rate,
                    channels=channels,
                    dtype="int16",
                    callback=callback,
                    blocksize=1024,
                ):
                    while not stop_event.is_set():
                        try:
                            chunk = q.get(timeout=0.1)
                            chunks.append(chunk)
                        except queue.Empty:
                            pass
            finally:
                listener.stop()
                listener.join()

        if not chunks:
            return np.zeros((0,), dtype=np.int16)

        audio = np.concatenate(chunks, axis=0)
        if channels == 1:
            audio = audio[:, 0]
        return audio.astype(np.int16)

    def write_pcm16_wav(
        self, audio: np.ndarray, path: Path, sample_rate: int = 16000
    ) -> None:
        with wave.open(str(path), "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(audio.tobytes())

    async def transcribe(self, audio: np.ndarray) -> str:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            wav_path = Path(f.name)

        try:
            await asyncio.to_thread(self.write_pcm16_wav, audio, wav_path, 16000)
            async with MLX_LOCK:
                result = await asyncio.to_thread(self.local_stt.generate, str(wav_path))
            return (getattr(result, "text", "") or "").strip()
        finally:
            try:
                wav_path.unlink(missing_ok=True)
            except Exception:
                pass

    def ask_ollama_sync(self, prompt: str) -> str:
        if self.llm_mode == "cloud":
            messages = [
                {
                    "role": "user",
                    "content": prompt,
                },
            ]

            result = "I am voice ai developed at santa cruz."
            for part in self.ollama_client.chat(
                "gpt-oss:120b", messages=messages, stream=True
            ):
                result += part["message"]["content"]

            # r.json()["response"].strip()
            return self.clean_for_tts(result.strip())
        else:
            r = requests.post(
                f"{self.ollama_base_url}/api/generate",
                json={
                    "model": self.llm_model,
                    "prompt": (
                        "You are a helpful voice AI assistant. "
                        "Keep responses concise, clear, and natural for speech.\n\n"
                        f"User: {prompt}\nAssistant:"
                    ),
                    "stream": False,
                },
                timeout=120,
            )
            r.raise_for_status()
            return r.json()["response"].strip()

    async def ask_ollama(self, prompt: str) -> str:
        return await asyncio.to_thread(self.ask_ollama_sync, prompt)

    def synthesize_sync(self, text: str):
        out_audio = None
        if self.tts_model and "kitten" in self.tts_model.lower():
            audio = self.local_tts.generate(text, voice=self.tts_voice, speed=1.2)
            out_audio = audio
        else:
            for result in self.local_tts.generate(
                text, voice=self.tts_voice
            ):
                out_audio = result.audio
        return out_audio

    async def synthesize(self, text: str):
        async with MLX_LOCK:
            return await asyncio.to_thread(self.synthesize_sync, text)

    def play_audio(self, audio_np, sample_rate: int = 24000) -> None:
        if audio_np is None:
            return

        audio_np = np.asarray(audio_np)
        if audio_np.ndim > 1:
            audio_np = audio_np.squeeze()

        if audio_np.dtype == np.int16:
            playback = audio_np.astype(np.float32) / 32767.0
        else:
            playback = audio_np.astype(np.float32)
            playback = np.clip(playback, -1.0, 1.0)

        sd.play(playback, samplerate=sample_rate)
        sd.wait()

    def clean_for_tts(self, text: str) -> str:
        # Remove markdown emphasis/code
        text = re.sub(r"[`*_#>-]+", " ", text)

        # Remove simple markdown table lines
        text = re.sub(r"^\|.*\|$", " ", text, flags=re.MULTILINE)
        text = re.sub(r"^\|?[-: ]+\|[-|: ]*$", " ", text, flags=re.MULTILINE)

        # Replace URLs with a simple placeholder or remove
        text = re.sub(r"https?://\S+", " ", text)

        # Collapse repeated whitespace/newlines
        text = re.sub(r"\s+", " ", text).strip()

        return text
