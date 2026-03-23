# Boba Repository Guide

## Overview
This repository currently contains two in-repo product areas plus shared docs:

- `chatur/`: a SwiftUI iOS app with location logging, camera capture, geospatial AR, notepad, finance tracking, and a pomodoro view.
- `sam/`: a Python voice assistant that records audio, transcribes with MLX STT, generates replies with Ollama, and speaks responses with local TTS.
- `docs/`: repository-level documentation.

The repo also integrates with an external Medha knowledge service when Sam is configured with Medha environment variables.

## Repository Map
- `chatur/chaturApp.swift`: SwiftUI app entry point.
- `chatur/Views/ContentView.swift`: top-level navigation container.
- `chatur/Views/SideMenuView.swift`: page menu and route enum.
- `chatur/Controllers/`: app state and persistence logic.
- `chatur/DatabaseStore.swift`: SQLite-backed shared database for location and photo records.
- `sam/run_voice_agent.py`: CLI entry point for the voice assistant.
- `sam/src/project.py`: main speech loop, hotkey handling, transcription, Ollama call, optional Medha retrieval, and playback.
- `sam/src/args.py`: command-line argument parsing.
- `sam/src/librarian_client.py`: HTTP client used by Sam to query the external Medha-compatible knowledge API.
- `sam/data/`: prompt and assistant text assets.
- `sam/readme.md`: user-facing voice assistant setup and controls.
- `docs/writeup.tex`: repository writeup.

## Chatur Notes
- The app uses `LocationController` as a shared `EnvironmentObject`.
- Location and photo metadata are persisted through `Database.shared`.
- Main navigation routes currently include `Home`, `Location Tracker`, `Camera`, `GeospatialAR`, `Notepad`, `Finance`, and `Pomodoro`.
- `MainPageView` shows current time/date, elapsed time from a fixed start date, current coordinates, water intake, and outside time.
- `CameraView` captures photos, applies optional effects, and stores photo metadata with location.
- `FinanceView` combines bill splitting with editable recurring hard-cost tracking.

## Sam Notes
- The voice assistant is macOS-oriented and uses local audio plus global keyboard hotkeys when available.
- The current record hotkey is `9`; release stops recording.
- The current interrupt hotkey is `x`; it stops transcription, reply generation, or playback as quickly as the current backend allows.
- `q` quits the assistant.
- STT defaults to Parakeet via `mlx-audio`.
- TTS supports KittenTTS and Kokoro-style MLX voices.
- LLM responses are generated through Ollama, usually against a local endpoint.
- Sam can optionally retrieve context from an external Medha service using `LIBRARIAN_URL`, `LIBRARIAN_TOKEN`, `LIBRARIAN_COLLECTIONS`, `LIBRARIAN_TOP_K`, and `LIBRARIAN_TIMEOUT_SECONDS`.

## External Integration Notes
- There is no in-repo `librarian/` directory in the current tree.
- If a task mentions Medha or Librarian retrieval, treat it as an external service dependency rather than an in-repo module.
- Keep Sam’s Medha-facing docs and code aligned with the current environment variable names and actual runtime behavior.

## Working Agreements
- Treat this as a mixed-language repo: Swift files should preserve existing SwiftUI patterns, and Python files should stay simple and script-friendly.
- Prefer minimal, targeted edits over broad rewrites.
- Do not touch `sam/.venv/`.
- Keep documentation aligned with the actual file layout and feature set.
- If you change controls or runtime behavior in `sam/src/project.py`, update user-facing docs in `sam/readme.md` or `docs/writeup.tex` when relevant.
- If you change Sam’s Medha integration behavior, update repo docs when those environment variables, retrieval assumptions, or interaction flows change.

## Useful Commands
- iOS app: open `boba.xcodeproj` in Xcode and run the `chatur` target.
- Voice assistant setup: `cd sam && uv sync`
- Voice assistant run: `cd sam && uv run run_voice_agent.py`
- Python syntax check: `python3 -m py_compile sam/src/project.py`

## Testing
- Swift tests live under `chaturTests/` and `chaturUITests/`.
- Python dev dependencies include `pytest`, `pytest-asyncio`, and `ruff`, though the current repo has little Python test coverage.
