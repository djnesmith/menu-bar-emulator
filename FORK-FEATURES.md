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

Don't use the in-app update button. It swaps this build for upstream's prebuilt release zip.

## Features

None yet.
