import AppKit

/// One key for a core that reads a real keyboard (the Apple II), in libretro's terms: the key's code, the character it
/// types, and the modifier keys held.
struct RetroKey {
    var down: Bool
    var code: UInt32
    var character: UInt32
    var modifiers: UInt16

    /// Keys with no fixed character. End and Home are left out: AppleWin uses them to reboot and to write its settings.
    private static let special: [UInt16: retro_key] = [
        36: RETROK_RETURN, 76: RETROK_RETURN, 48: RETROK_TAB, 53: RETROK_ESCAPE, 51: RETROK_BACKSPACE,
        117: RETROK_DELETE, 49: RETROK_SPACE, 123: RETROK_LEFT, 124: RETROK_RIGHT, 125: RETROK_DOWN, 126: RETROK_UP,
    ]

    /// nil for keys the core has no use for.
    init?(_ event: NSEvent) {
        let flags = event.modifierFlags
        modifiers = 0
        for (flag, mod) in [(NSEvent.ModifierFlags.shift, RETROKMOD_SHIFT), (.control, RETROKMOD_CTRL), (.option, RETROKMOD_ALT)]
        where flags.contains(flag) {
            modifiers |= UInt16(mod.rawValue)
        }

        // Left and right Option are the Open Apple and Solid Apple keys. Modifier keys arrive as flagsChanged.
        if event.type == .flagsChanged {
            switch event.keyCode {
            case 58: code = RETROK_LALT.rawValue
            case 61: code = RETROK_RALT.rawValue
            default: return nil
            }
            down = flags.contains(.option)
            character = 0
            return
        }

        down = event.type == .keyDown
        if let key = Self.special[event.keyCode] {
            code = key.rawValue
            character = key == RETROK_SPACE ? 0x20 : 0
            return
        }
        // The unshifted key is the code (as on a US keyboard); the shifted one is the character it types. Only printable
        // keys: End, Home, Page Up/Down and the F keys come through as control characters.
        guard let base = event.characters(byApplyingModifiers: [])?.unicodeScalars.first, (0x20...0x7E).contains(base.value)
        else { return nil }
        code = base.value
        let typed = event.characters(byApplyingModifiers: flags.intersection(.shift))?.unicodeScalars.first
        character = typed.map { $0.isASCII ? $0.value : 0 } ?? 0
    }
}
