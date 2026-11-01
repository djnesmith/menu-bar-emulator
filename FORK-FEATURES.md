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

## 2. Apple IIe

Apple IIe disk images (`.dsk`, `.do`, `.po`, `.woz`) play through AppleWin's libretro core ([audetto/AppleWin](https://github.com/audetto/AppleWin), GPL-2.0-or-later). No Apple ROM is built in. `patches/applewin-user-roms.patch` drops the 23 `.rom` files from AppleWin's build and reads them from the BIOS folder instead, under AppleWin's own file names. To boot a disk you need `Apple2e_Enhanced.rom`, `Apple2e_Enhanced_Video.rom` and `DISK2.rom` there (drag them into the library). If any are missing, the game doesn't start and the message names them. `DISK2-13sector.rom` is needed only for 13-sector disks.

The keyboard is the Apple II's. While an Apple II game is on screen with no panel open, every key goes to it, Escape included. ⌘ shortcuts still work. Left and right Option are Open Apple and Solid Apple. End and Home are never sent: AppleWin uses them to reboot and to write its settings. Leave the game with the Library button or the controller's Select button. Keys are queued and handed to the core between frames. Other systems keep their keys exactly as before.

- Commits: the one that adds this entry (`git log -S appleIIeROMs --oneline`)
- Files: `build-cores.sh` (AppleWin pin and build), `patches/applewin-user-roms.patch` (fork-only), `MenuBarEmulator/Library.swift` (`GameSystem.apple2`), `Core/Emulator.swift` (keyboard callback, key queue, ROM check), `Core/AppModel.swift` (`handle` sends keys to the game), `Core/FloatingWindow.swift` (key monitor also gets `.flagsChanged`), `Core/RetroKeyboard.swift` (fork-only), `Core/Covers.swift` (no box art), `Views/ConsoleArt.swift` (`appleIIe()`), `MenuBarEmulatorTests/AppleIIeTests.swift` (fork-only)
- After a merge: if upstream changes `build-cores.sh`, keep the AppleWin block. If upstream adds a `GameSystem` case or a switch over it, the compiler flags any `.apple2` case left out. If upstream changes `AppModel.handle` or the key monitor, the Apple II branch must stay first in `handle`.
- Check: `xcodebuild test` with the same flags as the build; `AppleIIeTests` passes (4 tests). `nm BuiltCores/applewin.libretro | grep -i -E "_(rom|ROM)(_len)?$"` prints nothing: `xxd` names each embedded file's symbol after it, so no `Apple2e_Enhanced_rom` means no ROM is built in. By hand: put the three ROM files and a disk image in the library, open the disk, type `CATALOG` and Return at the prompt.
