# Boba Repo Skill

Use this repo skill when working anywhere inside `boba/`.

## Purpose
Help an agent quickly orient itself in a repository that currently contains:

- a SwiftUI iOS app in `chatur/`
- Xcode project metadata in `boba.xcodeproj/`
- repository documentation in `docs/`

## Fast Orientation
Start with these files:

1. `AGENTS.md`
2. `chatur/chaturApp.swift`
3. `chatur/Views/ContentView.swift`
4. `chatur/Views/SideMenuView.swift`
5. `chatur/DatabaseStore.swift`
6. `chatur/Controllers/LocationController.swift`
7. `chatur/Controllers/PhotoRecordController.swift`
8. `docs/writeup.tex`

## Mental Model
- `chatur/` is a personal utility app with several tools behind a side menu.
- `ContentView` and `SideMenuView` define the app routing surface.
- Controllers and `DatabaseStore.swift` hold most persistence behavior.
- `docs/` should reflect current routes, storage tables, and folder layout.

## Task Routing
- If the task mentions camera, location, AR, notes, finance, or pomodoro, inspect `chatur/`.
- If the task is documentation, sync wording with real file names, current menu routes, persistence behavior, and the actual tree.
- If the task concerns storage, inspect `DatabaseStore.swift` and related controllers before changing docs.

## Editing Guidance
- Preserve the current SwiftUI style instead of introducing new architecture.
- When changing user-visible behavior, update nearby documentation in the same turn if possible.
- Keep edits narrow and avoid unnecessary formatting churn.
- Be aware that the models folder is named `chatur/ Models/` (with a leading space), and reference it exactly when documenting paths.

## Validation
- For docs-only edits, confirm paths, feature names, routes, and storage details against the repo tree.
- For Swift edits, prefer targeted review of affected files if full Xcode testing is not available.
