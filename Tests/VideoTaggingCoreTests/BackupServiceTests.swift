import Foundation
import Testing
@testable import VideoTaggingCore

@Suite struct BackupServiceTests {
    @Test func writesTimestampedCopyInBackupsFolder() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let srt = tmp.appendingPathComponent("clip.srt")
        try "1\n00:00:00,000 --> 00:00:01,000\nhi".write(to: srt, atomically: true, encoding: .utf8)

        let service = BackupService()
        let backup = try service.backup(srt: srt, timestamp: "20260603-101500")

        #expect(backup.lastPathComponent == "clip.20260603-101500.srt")
        #expect(backup.deletingLastPathComponent().lastPathComponent == ".backups")
        #expect(FileManager.default.fileExists(atPath: backup.path))
        let restored = try String(contentsOf: backup, encoding: .utf8)
        #expect(restored.contains("hi"))
    }

    @Test func backingUpMissingFileIsNoOp() throws {
        let missing = URL(fileURLWithPath: "/nope/clip.srt")
        let result = try BackupService().backupIfExists(srt: missing, timestamp: "t")
        #expect(result == nil)
    }
}
