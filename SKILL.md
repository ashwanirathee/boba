# Boba Repo Skill

Use this repo skill when working anywhere inside `boba/`.

## Purpose
Help an agent quickly orient itself in a repository that combines:

- a SwiftUI iOS app in `chatur/`
- a Python voice assistant in `sam/`
- lightweight repository docs in `docs/`
- an optional external Medha knowledge-service integration used by Sam

## Fast Orientation
Start with these files:

1. `AGENTS.md`
2. `chatur/chaturApp.swift`
3. `chatur/Views/ContentView.swift`
4. `chatur/Views/SideMenuView.swift`
5. `sam/run_voice_agent.py`
6. `sam/src/project.py`
7. `sam/src/librarian_client.py`
8. `sam/readme.md`

## Mental Model
- `chatur/` is a personal utility app with several tools behind a side menu.
- `sam/` is a command-line speech loop, not a web service.
- `sam/src/project.py` is the main operational file for recording, transcription, LLM prompting, optional Medha retrieval, speech synthesis, and playback.
- Medha retrieval is an external dependency configured through environment variables, not an in-repo knowledge-base module.
- `docs/` should describe the current repo tree, not historical folders that no longer exist here.

## Task Routing
- If the task mentions camera, location, AR, notes, finance, or pomodoro, inspect `chatur/`.
- If the task mentions hotkeys, recording, STT, TTS, Ollama, prompts, or interruption behavior, inspect `sam/`.
- If the task mentions Medha, Librarian retrieval, RAG, or knowledge queries from Sam, inspect `sam/src/project.py` and `sam/src/librarian_client.py`.
- If the task is documentation, sync wording with real file names, current controls, current defaults, and the actual repo layout.

## Editing Guidance
- Preserve the current SwiftUI style instead of introducing new architecture.
- Preserve the current Python script structure unless a refactor is clearly needed.
- Avoid editing generated or dependency-managed directories such as `sam/.venv/`.
- When changing user-visible behavior, update nearby documentation in the same turn if possible.
- When describing Sam controls, include the current `9` hold-to-record behavior and `x` interrupt behavior when relevant.

## Validation
- For Python-only edits, at minimum run `python3 -m py_compile` on changed modules.
- For docs-only edits, confirm paths, feature names, commands, and external dependency descriptions against the repo tree.
- For Swift edits, prefer targeted review of affected files if full Xcode testing is not available.
