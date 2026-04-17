# Boba Repository Guide

## Overview
This repository currently contains one in-repo product area plus shared docs:

- `chatur/`: a SwiftUI iOS app with location logging, camera capture, geospatial views, notepad, finance tracking, and a pomodoro timer.
- `docs/`: repository-level documentation.
- `boba.xcodeproj/`: Xcode project metadata for building and running the app.

## Repository Map
- `chatur/chaturApp.swift`: SwiftUI app entry point.
- `chatur/Views/ContentView.swift`: top-level navigation container.
- `chatur/Views/SideMenuView.swift`: page menu and route enum.
- `chatur/Controllers/`: app state and persistence logic.
- `chatur/DatabaseStore.swift`: SQLite-backed shared database for location and photo records.
- `chatur/ Models/`: codable models used by controllers and views.
- `chaturTests/`, `chaturUITests/`: unit/UI test targets.
- `docs/writeup.tex`: repository writeup.

## Chatur Notes
- The app uses `LocationController` as a shared `EnvironmentObject`.
- Location and photo metadata are persisted through `Database.shared`.
- Main navigation routes currently include `Home`, `Location Tracker`, `Camera`, `GeospatialAR`, `Notepad`, `Finance`, and `Pomodoro`.
- `MainPageView` shows current date/time, elapsed time from a fixed baseline date, coordinates, daily water intake, and outside-time totals.
- `LocationView` renders a map trail from recent location samples and overlays nearby photo pins.
- `CameraView` captures photos, supports effect preview/processing, and records metadata in SQLite.
- `FinanceView` combines shared-bill math with editable recurring hard-cost tracking persisted in `UserDefaults`.
- `NotepadView` persists freeform text with `@AppStorage`.
- `PomodoroView` provides focus/break cycles with presets and start/pause/reset controls.

## Persistence Notes
- SQLite tables currently include `locations`, `photos`, `water`, and `outside_time`.
- Daily counters (water and outside time) are day-keyed by `YYYY-MM-DD`.
- Hard-cost finance items are JSON-encoded into `UserDefaults` under a single key.
- Notepad text is persisted in `UserDefaults` via `@AppStorage("notepad.text")`.

## Working Agreements
- Treat this as a Swift-first repo: preserve existing SwiftUI patterns and keep edits targeted.
- Prefer minimal, targeted edits over broad rewrites.
- Keep documentation aligned with the actual file layout and feature set.
- If you change menu routes in `SideMenuView`, update docs that list app screens.
- If you change persistence schema in `DatabaseStore.swift`, update docs that mention tables or data storage behavior.

## Useful Commands
- iOS app: open `boba.xcodeproj` in Xcode and run the `chatur` target.
- CLI build check: `xcodebuild -project boba.xcodeproj -scheme chatur -destination 'generic/platform=iOS Simulator' build`
- CLI tests: `xcodebuild test -project boba.xcodeproj -scheme chatur -destination 'platform=iOS Simulator,name=iPhone 15'`

## Testing
- Swift tests live under `chaturTests/` and `chaturUITests/`.
- There is currently light automated coverage; most feature validation is manual through simulator/device runs.
