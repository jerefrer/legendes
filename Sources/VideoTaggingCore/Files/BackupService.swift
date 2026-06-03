import Foundation

public struct BackupService: Sendable {
    public init() {}

    /// Copy `srt` into a sibling `.backups/` folder as `<name>.<timestamp>.srt`.
    @discardableResult
    public func backup(srt: URL, timestamp: String) throws -> URL {
        let folder = srt.deletingLastPathComponent().appendingPathComponent(".backups")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = srt.deletingPathExtension().lastPathComponent
        let dest = folder.appendingPathComponent("\(name).\(timestamp).srt")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: srt, to: dest)
        return dest
    }

    @discardableResult
    public func backupIfExists(srt: URL, timestamp: String) throws -> URL? {
        guard FileManager.default.fileExists(atPath: srt.path) else { return nil }
        return try backup(srt: srt, timestamp: timestamp)
    }
}
