import AppKit
import XCTest
@testable import MenuBarEmulator

/// Fork feature: Apple IIe through AppleWin's libretro core.
final class AppleIIeTests: EmulatorTestCase {
    func testDiskImagesAreAppleIIeGamesAndROMFilesStayBIOS() throws {
        for ext in ["dsk", "do", "po", "woz", "DSK"] {
            XCTAssertEqual(GameSystem(rom: URL(filePath: "/x/Oregon Trail.\(ext)")), .apple2, ext)
        }
        XCTAssertNil(GameSystem(rom: URL(filePath: "/x/Apple2e_Enhanced.rom")))
        XCTAssertEqual(GameSystem.apple2.core, "applewin")
        XCTAssertNil(Covers.url(name: "Oregon Trail", system: .apple2), "libretro-thumbnails has no Apple II set")
        XCTAssertEqual(AppInfo.credits.first { $0.name == "AppleWin" }?.license, "GNU GPL 2.0", "GPL needs the credit")

        let library = Library(root: temp.appending(path: "Library"))
        let result = library.importFiles([try makeFile("Oregon Trail.dsk"), try makeFile("DISK2.rom")])
        XCTAssertEqual(result.games.map(\.lastPathComponent), ["Oregon Trail.dsk"])
        XCTAssertEqual(result.bios, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: library.root.appending(path: "BIOS/DISK2.rom").path))
    }

    func testMissingROMsAreNamedBeforeTheCoreStarts() throws {
        let library = Library(root: temp.appending(path: "Library"))
        library.importFiles([try makeFile("Oregon Trail.dsk"), try makeFile("DISK2.rom")])
        let emulator = makeEmulator(library)
        emulator.play(try XCTUnwrap(library.roms.first))
        XCTAssertNil(emulator.game)
        let error = try XCTUnwrap(emulator.error)
        XCTAssertTrue(error.contains("Apple2e_Enhanced.rom, Apple2e_Enhanced_Video.rom"), error)
        XCTAssertFalse(error.contains("DISK2.rom"), "only the missing ones are named")
    }

    /// A library with zero-filled stand-ins for Apple's ROMs and blank disks (no Apple data).
    private func libraryWithBlankDisks(_ names: [String]) throws -> Library {
        let library = Library(root: temp.appending(path: "Library"))
        var files: [URL] = []
        for name in names {
            let disk = temp.appending(path: name)
            try Data(count: 143_360).write(to: disk)
            files.append(disk)
        }
        for (name, size) in zip(Emulator.appleIIeROMs, [16_384, 4_096, 256]) {
            let rom = temp.appending(path: name)
            try Data(count: size).write(to: rom)
            files.append(rom)
        }
        library.importFiles(files)
        return library
    }

    /// AppleWin looked for its program folder next to the app and threw when it wasn't there, so no disk ever started.
    /// Zero-filled stand-ins under the ROMs' names are enough: the load failed before any ROM was read.
    func testDiskStartsWithROMsInPlace() throws {
        let library = try libraryWithBlankDisks(["Blank.dsk"])
        let emulator = makeEmulator(library)
        emulator.play(try XCTUnwrap(library.roms.first))
        defer { emulator.stop() }
        XCTAssertNil(emulator.error)
        XCTAssertNotNil(emulator.game)
    }

    func testMultiDiskGamesAreOneGame() throws {
        func names(_ files: [String]) -> [[String]] {
            DiskSets.group(files.map { URL(filePath: "/x/\($0)") }).values.map { $0.map(\.lastPathComponent) }.sorted { $0[0] < $1[0] }
        }
        XCTAssertEqual(names(["cap2.dsk", "cap1.dsk"]), [["cap1.dsk", "cap2.dsk"]])
        XCTAssertEqual(names(["Ultima (Disk 2 of 2).dsk", "Ultima (Disk 1 of 2).dsk"]),
                       [["Ultima (Disk 1 of 2).dsk", "Ultima (Disk 2 of 2).dsk"]])
        XCTAssertEqual(names(["Karateka - Side B.woz", "Karateka - Side A.woz"]), [["Karateka - Side A.woz", "Karateka - Side B.woz"]])
        XCTAssertEqual(names(["Game Disk 1.do", "game disk 2.do", "Game Disk 3.do"]).first?.count, 3)
        XCTAssertEqual(names(["Ultima 4.dsk", "Ultima 5.dsk"]), [], "a sequel isn't a second disk")
        XCTAssertEqual(names(["cap2.dsk"]), [], "one disk isn't a set")
        XCTAssertEqual(names(["Pokemon1.gba", "Pokemon2.gba"]), [], "Apple II only")

        let library = try libraryWithBlankDisks(["cap1.dsk", "cap2.dsk", "Oregon Trail.dsk"])
        XCTAssertEqual(library.roms.map(\.lastPathComponent).sorted(), ["Oregon Trail.dsk", "cap1.dsk"], "disk 2 is part of cap1")
        XCTAssertEqual(library.diskSets.values.first?.map(\.lastPathComponent), ["cap1.dsk", "cap2.dsk"])
    }

    func testSwappingDisks() throws {
        let library = try libraryWithBlankDisks(["cap1.dsk", "cap2.dsk", "Oregon Trail.dsk"])
        // One emulator, like the app: AppleWin is one machine, so a second Emulator would share (and break) it.
        let emulator = makeEmulator(library)
        emulator.play(try XCTUnwrap(library.roms.first))
        XCTAssertNil(emulator.error)
        XCTAssertEqual(emulator.disks.map(\.lastPathComponent), ["cap1.dsk", "cap2.dsk"])
        XCTAssertEqual(emulator.currentDisk, 0)
        emulator.insertDisk(1)
        XCTAssertEqual(emulator.currentDisk, 1, "the core reports disk 2 in the drive")
        emulator.nextDisk()
        XCTAssertEqual(emulator.currentDisk, 0, "Next Disk wraps around")
        emulator.insertDisk(1)
        emulator.stop()

        emulator.play(try XCTUnwrap(library.roms.first))
        XCTAssertEqual(emulator.currentDisk, 1, "coming back resumes with disk 2 in the drive")
        emulator.stop()

        let single = try XCTUnwrap(library.roms.first { $0.lastPathComponent == "Oregon Trail.dsk" })
        emulator.play(single)
        defer { emulator.stop() }
        XCTAssertNil(emulator.error)
        XCTAssertEqual(emulator.disks, [], "no Change Disk for a one-disk game")
    }

    func testKeysBecomeLibretroKeys() throws {
        let a = try XCTUnwrap(RetroKey(key(0, "a")))
        XCTAssertEqual([a.code, a.character], [97, 97])
        XCTAssertTrue(a.down)
        let shifted = try XCTUnwrap(RetroKey(key(18, "!", down: false, flags: .shift)))
        XCTAssertEqual([shifted.code, shifted.character], [0x31, 0x21], "code is the unshifted key, character the typed one")
        XCTAssertFalse(shifted.down)
        XCTAssertEqual(shifted.modifiers, UInt16(RETROKMOD_SHIFT.rawValue))
        XCTAssertEqual(RetroKey(key(8, "c", flags: .control))?.modifiers, UInt16(RETROKMOD_CTRL.rawValue))

        let codes: [(UInt16, retro_key)] = [(36, RETROK_RETURN), (53, RETROK_ESCAPE), (51, RETROK_BACKSPACE),
                                            (48, RETROK_TAB), (126, RETROK_UP), (123, RETROK_LEFT)]
        for (keyCode, expected) in codes {
            XCTAssertEqual(RetroKey(key(keyCode))?.code, expected.rawValue, "key \(keyCode)")
        }
        XCTAssertNil(RetroKey(key(119)), "End reboots in AppleWin, so it's never sent")
        XCTAssertNil(RetroKey(key(115)), "Home writes AppleWin's settings file")

        let option = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 58, keyDown: true))
        option.type = .flagsChanged
        option.flags = .maskAlternate
        let openApple = try XCTUnwrap(RetroKey(try XCTUnwrap(NSEvent(cgEvent: option))))
        XCTAssertEqual(openApple.code, RETROK_LALT.rawValue, "left Option is Open Apple")
        XCTAssertTrue(openApple.down)
    }

    func testOtherScreensIgnoreModifierKeys() throws {
        let model = makeModel()
        let option = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 58, keyDown: true))
        option.type = .flagsChanged
        option.flags = .maskAlternate
        XCTAssertFalse(model.emulator.hasKeyboard)
        XCTAssertFalse(model.handle(try XCTUnwrap(NSEvent(cgEvent: option))), "modifier changes pass through untouched")
    }
}
