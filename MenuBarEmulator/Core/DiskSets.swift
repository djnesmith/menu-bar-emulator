import Foundation

/// Apple II games that come on several disks: "cap1.dsk" and "cap2.dsk", "Ultima (Disk 1).dsk" and "(Disk 2)",
/// "Game Side A.dsk" and "Side B". The library shows a set as its first disk, and the game gets all of them.
enum DiskSets {
    /// Each set of two or more disks, keyed by its first disk, in disk order.
    static func group(_ roms: [URL]) -> [URL: [URL]] {
        var sets: [String: [(number: Int, url: URL)]] = [:]
        for rom in roms where GameSystem(rom: rom) == .apple2 {
            guard let (name, number) = split(rom.deletingPathExtension().lastPathComponent) else { continue }
            sets[name, default: []].append((number, rom))
        }
        var result: [URL: [URL]] = [:]
        for disks in sets.values where Set(disks.map(\.number)).count == disks.count && disks.count > 1 {
            let sorted = disks.sorted { $0.number < $1.number }.map(\.url)
            result[sorted[0]] = sorted
        }
        return result
    }

    /// "cap1" → ("cap", 1), "Ultima (Disk 2 of 3)" → ("ultima", 2), "Game - Side B" → ("game", 2). A number needs
    /// "Disk"/"Side" before it or a letter right before it, so "Ultima 4" and "Ultima 5" stay two games.
    static func split(_ stem: String) -> (name: String, number: Int)? {
        let labelled = /(?i)^(.*?)[\s._\-,]*[\(\[]?\s*(?:disk|disc|side)\s*([0-9]{1,2}|[a-d])(?:\s*of\s*[0-9]{1,2})?\s*[\)\]]?$/
        let attached = /^(.*[A-Za-z])([0-9]{1,2})$/
        let name: Substring, number: Substring
        if let match = stem.wholeMatch(of: labelled) {
            (name, number) = (match.1, match.2)
        } else if let match = stem.wholeMatch(of: attached) {
            (name, number) = (match.1, match.2)
        } else {
            return nil
        }
        let key = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty else { return nil }
        if let value = Int(number) { return (key, value) }
        return (key, Int(number.lowercased().unicodeScalars.first!.value) - 96) // a → 1
    }

    /// An .m3u playlist of `disks`, the way AppleWin reads a multi-disk game. Written fresh for each play.
    static func playlist(for disks: [URL]) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "Disk Sets")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: disks[0].deletingPathExtension().lastPathComponent + ".m3u")
        try (disks.map(\.path).joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
