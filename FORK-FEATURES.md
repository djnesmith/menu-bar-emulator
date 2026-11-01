# Fork features

Read this before merging upstream. Every item must still work after the merge.

Branch: `main`. Base: `upstream/main` (Kiasora/menu-bar-emulator), last merged at `b143870` (6 commits past tag `v1.0.5`).

Needs macOS 26+ on Apple Silicon, Xcode, and `brew install cmake ninja`. Build the cores, then a Release app:

```sh
./build-cores.sh
xcodebuild -project MenuBarEmulator.xcodeproj -scheme MenuBarEmulator -configuration Release -destination 'platform=macOS' -derivedDataPath build/dd CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= build
```

The project names no signing team, so this signs ad hoc. Copy `build/dd/Build/Products/Release/MenuBarEmulator.app` to `/Applications` (`ditto`, no sudo). Tests: `xcodebuild test` with the same project, scheme and destination (ROM tests skip without fixtures).

`build-cores.sh` skips any core already in `cores/`. Delete that core's folder after upstream changes its pinned commit.

## Features

## 1. No in-app updates

The app never checks for updates and can't replace itself. Removed the launch call `model.updates.start()` (it also ran a daily timer) and the Settings › About "Check for Updates" row. With nothing calling `UpdateChecker.check`, the update banner and its Update button (`AppUpdater`, which swaps in upstream's prebuilt release zip) never appear. Upstream's code for both stays, so merges stay small. We follow upstream through git, not the app. Box-art downloads are unchanged.

- Commits: the one that adds this entry (`git log -S "No in-app updates" --oneline`)
- Files: `MenuBarEmulator/MenuBarEmulatorApp.swift`, `MenuBarEmulator/Views/SettingsView.swift`
- Check: `git grep -n -E "updates\.start\(|checkForUpdates\(\) \}" -- MenuBarEmulator` prints nothing. If upstream adds a new caller of `updates.check`, `updates.start` or `updater.install`, remove it too. By hand: launch the app and watch `log stream --predicate 'process == "MenuBarEmulator"' --level debug | grep -i -E "api.github.com|update.json"` for 30s; nothing prints. Settings › About has no Check for Updates row.
