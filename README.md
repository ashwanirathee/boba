# Boba

Boba is a SwiftUI iOS workspace centered on the `chatur` app.

The app combines several personal utility tools in one side-menu-driven interface:

- Home dashboard (date/time, elapsed baseline time, coordinates)
- Location tracking with map trail and nearby photo pins
- Camera capture with live effect preview and photo metadata logging
- Geospatial screens for location-oriented AR-style workflows
- Notepad persisted with local app storage
- Finance utilities for bill split and recurring hard costs
- Pomodoro timer with focus/break presets

## Repository Layout

- `chatur/`: iOS app source, controllers, views, assets, and models
- `boba.xcodeproj/`: Xcode project metadata
- `chaturTests/`, `chaturUITests/`: test targets
- `docs/`: repository documentation
- `AGENTS.md`, `SKILL.md`: repository guidance for coding agents

## Persistence Snapshot

The app stores data using a mix of SQLite and `UserDefaults`:

- SQLite tables in `chatur/DatabaseStore.swift`: `locations`, `photos`, `water`, `outside_time`
- `@AppStorage("notepad.text")` for notepad content
- JSON-encoded recurring finance items under a `UserDefaults` key managed by `HardCostController`

## Run The App

1. Open `boba.xcodeproj` in Xcode.
2. Select the `chatur` scheme.
3. Run on an iOS Simulator or device.

## Optional CLI Checks

Build:

```bash
xcodebuild -project boba.xcodeproj -scheme chatur -destination 'generic/platform=iOS Simulator' build
```

Test:

```bash
xcodebuild test -project boba.xcodeproj -scheme chatur -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Notes

- The models folder in this repository is named `chatur/ Models/` (with a leading space).
- Automated test coverage is currently light; many feature checks are still manual.
