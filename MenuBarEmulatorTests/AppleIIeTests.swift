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
