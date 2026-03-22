
# Voice AI Assistant

Realtime speech loop that keeps everything on-device: Parakeet (STT) and Kokoro (TTS) run with Apple MLX, while small Ollama models deliver text responses.

## Prerequisites
- macOS with Python 3.11+ and [uv](https://github.com/astral-sh/uv) installed.
- Homebrew packages:
	- `brew install espeak-ng` (provides the phoneme tables Kokoro needs).
	- `brew install portaudio ffmpeg` (audio I/O + conversion helpers for `sounddevice`).
- A running Ollama instance (default `http://127.0.0.1:11434`) with the target model pulled, e.g. `ollama pull qwen3:8b`.

## Setup
```bash
cd app/voice-ai
uv sync
```

Optional overrides live in `.env.local` (loaded automatically):
```bash
LOCAL_STT_ID=mlx-community/parakeet-tdt-0.6b-v3
LOCAL_TTS_ID=mlx-community/Kokoro-82M-bf16
LOCAL_TTS_VOICE=af_heart
OLLAMA_MODEL=qwen3:8b
OLLAMA_BASE_URL=http://127.0.0.1:11434
```

## Run the assistant
Ensure Kokoro can find the phoneme tables, then launch through uv:
```bash
cd app/voice-ai
ESPEAK_DATA_PATH="$(brew --prefix espeak-ng)/share/espeak-ng-data" \
	uv run src/agent.py
```

Controls: `1` starts recording, `2` stops, `q` exits. After recording stops the assistant transcribes locally, calls the configured Ollama model, and speaks the cleaned reply.


## Troubleshooting
- **`phontab` missing**: confirm the data directory exists (`ls $(brew --prefix espeak-ng)/share/espeak-ng-data/phontab`). Export `ESPEAK_DATA_PATH` (or `ESPEAKNG_DATA`) before running so Kokoro can locate that folder.
- **No microphone access**: macOS may block the CLI on first run—approve mic usage in `System Settings → Privacy & Security → Microphone`.
- **Remote inference**: a future `--utilize-remote` flag will call Ollama Cloud with an API key; for now all completions route to the local Ollama endpoint configured above.

### Resources
- https://huggingface.co/spaces/Pendrokar/TTS-Spaces-Arena
- https://github.com/hexgrad/kokoro