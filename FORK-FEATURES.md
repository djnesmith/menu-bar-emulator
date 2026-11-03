# Fork features

Read this before merging upstream. Every item must still work after the merge.

Branch: `main`. Base: `upstream/main` (Kiasora/menu-bar-emulator), last merged at `92d317b` (1 commit past tag `v1.2.1`).

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

Apple IIe disk images (`.dsk`, `.do`, `.po`, `.woz`) play through AppleWin's libretro core ([audetto/AppleWin](https://github.com/audetto/AppleWin), GPL-2.0-or-later). No Apple ROM is built in. `patches/applewin-user-roms.patch` drops the 23 `.rom` files from AppleWin's build and reads them from the BIOS folder instead, under AppleWin's own file names. It also drops `Cousine-Regular.ttf`, the SDL frontend's font: in AppleWin's repo it links into the imgui submodule, which the source download doesn't include. And it fixes an AppleWin bug that stopped every disk from starting: at load, the core looked for its program folder at a path left over from its build (`ROOT_PATH`, `../../applewin` from the app), and `std::filesystem::canonical` throws when that folder is missing. The patch uses `weakly_canonical`, which doesn't throw; AppleWin then falls back to the current folder, used only for debug symbols and printer output. To boot a disk you need `Apple2e_Enhanced.rom`, `Apple2e_Enhanced_Video.rom` and `DISK2.rom` there (drag them into the library). If any are missing, the game doesn't start and the message names them. `DISK2-13sector.rom` is needed only for 13-sector disks.

The keyboard is the Apple II's. While an Apple II game is on screen with no panel open, every key goes to it, Escape included. ⌘ shortcuts still work. Left and right Option are Open Apple and Solid Apple. End and Home are never sent: AppleWin uses them to reboot and to write its settings. Leave the game with the Library button or the controller's Select button. Keys are queued and handed to the core between frames. Other systems keep their keys exactly as before.

A controller is the Apple II joystick. AppleWin has no joystick until the app plugs one into port 0 (`retro_set_controller_port_device`, `libretro.cpp:148`, joypad case at `:166-167`, pinned commit), so the app plugs in a joypad after each Apple IIe game loads (`Emulator.hasJoystick`). The d-pad or left stick moves it, always at full tilt. B (right face button) is button 0 and A (bottom) is button 1. Left and right Option are also buttons 0 and 1. The arrow keys stay keys, not the joystick.

Games on more than one disk play as one game. Files with the same name and a disk number (`cap1.dsk`/`cap2.dsk`, `Ultima (Disk 1 of 2).dsk`/`(Disk 2 of 2)`, `Game - Side A.woz`/`Side B`) show in the library as the first disk only (`DiskSets.group`). A number counts only after "Disk", "Disc" or "Side", or right after a letter, so `Ultima 4` and `Ultima 5` stay two games. Opening the game writes an `.m3u` of all its disks to the temp folder, and AppleWin loads that with its own m3u reader (`source/frontends/libretro/libretro.cpp:347-349` at the pinned commit, before our patch). The app answers `RETRO_ENVIRONMENT_GET_DISK_CONTROL_INTERFACE_VERSION` and takes `RETRO_ENVIRONMENT_SET_DISK_CONTROL_EXT_INTERFACE` (AppleWin offers it at `libretro.cpp:255-261`, same commit), for AppleWin only, so other cores are unchanged. To change disks: the game's ⋯ menu › Change Disk (lists each disk, checks the one in the drive), ⌘D (next disk), or Next Disk in the Game Menu (controller). Each one ejects, picks and inserts. Save states and the resume point keep the disk that was in the drive. A save state also carries AppleWin's list of disks, so one made before a disk was added (playing `cap1` alone, then adding `cap2`) lists too few; each swap first puts the full list back (`Emulator.restoreDiskList`). Removing the game trashes all its disks.

The app names Apple IIe wherever it lists its systems: the empty library's text, the About credits (AppleWin, GPL 2.0, which the license requires), the trademark line, and the README. The empty library's row of floating consoles has six drawings instead of five, each 5/6 the size, so the row keeps its width.

- Commits: the one that adds this entry (`git log -S appleIIeROMs --oneline`)
- Files: `build-cores.sh` (AppleWin pin and build), `MenuBarEmulator.xcodeproj/project.pbxproj` (`applewin.libretro` in Copy Cores, IDs `C1…08`/`C2…08`: upstream took `…07` for MoltenVK), `patches/applewin-user-roms.patch` (fork-only), `MenuBarEmulator/Library.swift` (`GameSystem.apple2`), `Core/Emulator.swift` (keyboard callback, key queue, ROM check), `Core/AppModel.swift` (`handle` sends keys to the game), `Core/FloatingWindow.swift` (key monitor also gets `.flagsChanged`), `Core/RetroKeyboard.swift` (fork-only), `Core/DiskSets.swift` (fork-only), `Library.swift` (`diskSets`, `reload`, `remove`), `Views/GameView.swift` (Change Disk menu), `Views/Panels.swift` (Next Disk), `Core/AppModel.swift` (⌘D), `Core/Covers.swift` (no box art), `Views/ConsoleArt.swift` (`appleIIe()`), `Views/LibraryView.swift` (empty-library text, `FloatingConsoles`), `Core/AppInfo.swift` (credit), `Views/SupportViews.swift` (trademark line), `README.md`, `MenuBarEmulatorTests/AppleIIeTests.swift` (fork-only)
- After a merge: if upstream changes `build-cores.sh`, keep the AppleWin block. If upstream adds a `GameSystem` case or a switch over it, the compiler flags any `.apple2` case left out. If upstream changes `AppModel.handle` or the key monitor, the Apple II branch must stay first in `handle`. If upstream rewrites a line that lists the systems, add Apple IIe back: `git grep -n -E "Game Gear (and|are)" -- MenuBarEmulator README.md` finds the lists, and each should also say Apple IIe.
- Check: `xcodebuild test` with the same flags as the build; `AppleIIeTests` passes (9 tests; `testControllerIsTheJoystick` checks the joypad is plugged in; `testSwappingDisks` swaps two blank stand-in disks; `testSwappingDisksAfterAddingDiskTwo` swaps after resuming from a one-disk save; `testDiskStartsWithROMsInPlace` boots a blank disk with zero-filled stand-in ROMs and fails with the AppleWin bug back). `nm BuiltCores/applewin.libretro | grep -E "_(rom|ROM)_len$"` prints nothing: `xxd` names each embedded file's symbols after it, so no `Apple2e_Enhanced_rom_len` means no ROM is built in (`_z80bios_rom` is the Z80 card's empty memory, not a file). By hand: put the three ROM files and a disk image in the library, open the disk, type `CATALOG` and Return at the prompt.
