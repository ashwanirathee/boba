# Boba Repo Skill

Use this repo skill when working anywhere inside `boba/`.

## Purpose
Help an agent quickly orient itself in a repository that combines:

- a SwiftUI iOS app in `chatur/`
- a Python voice assistant in `sam/`
- lightweight documentation in `docs/`

## Fast Orientation
Start with these files:

1. `AGENTS.md`
2. `chatur/chaturApp.swift`
3. `chatur/Views/ContentView.swift`
4. `chatur/Views/SideMenuView.swift`
5. `sam/run_voice_agent.py`
6. `sam/src/project.py`
7. `sam/readme.md`

## Mental Model
- `chatur/` is a personal utility app with several tools behind a side menu.
- `Controllers/` own state and persistence logic.
- `Views/` are mostly feature screens and simple SwiftUI compositions.
- `sam/` is a command-line speech loop, not a web service.
- `sam/src/project.py` is the main operational file for recording, transcription, LLM prompting, and playback.

## Task Routing
- If the task mentions camera, location, AR, notes, finance, or pomodoro, inspect `chatur/`.
- If the task mentions hotkeys, recording, STT, TTS, Ollama, or prompts, inspect `sam/`.
- If the task is documentation, sync wording with real file names, current controls, and current defaults.

## Editing Guidance
- Preserve the current SwiftUI style instead of introducing new architecture.
- Preserve the current Python script structure unless a refactor is clearly needed.
- Avoid editing generated or dependency-managed directories such as `sam/.venv/`.
- When changing user-visible behavior, update nearby documentation in the same turn if possible.

## Validation
- For Python-only edits, at minimum run `python3 -m py_compile` on changed modules.
- For docs-only edits, confirm paths, feature names, and commands against the repo tree.
- For Swift edits, prefer targeted review of affected files if full Xcode testing is not available.
