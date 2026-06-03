import Foundation
import Testing
@testable import VideoTaggingCore

@Suite struct FilePairingTests {
    // Injects which sibling files "exist".
    func pairer(existing: Set<String> = []) -> FilePairing {
        FilePairing { url in existing.contains(url.path) }
    }

    @Test func videoWithSiblingSrt() throws {
        let video = URL(fileURLWithPath: "/v/clip.mp4")
        let srt = URL(fileURLWithPath: "/v/clip.srt")
        let result = try pairer(existing: [srt.path]).resolve([video])
        #expect(result.video == video)
        #expect(result.srt == srt)
    }

    @Test func videoWithoutSrtStartsFresh() throws {
        let video = URL(fileURLWithPath: "/v/clip.mp4")
        let result = try pairer().resolve([video])
        #expect(result.video == video)
        #expect(result.srt == nil)
    }

    @Test func srtWithSiblingVideoOpensVideo() throws {
        let srt = URL(fileURLWithPath: "/v/clip.srt")
        let video = URL(fileURLWithPath: "/v/clip.mp4")
        let result = try pairer(existing: [video.path]).resolve([srt])
        #expect(result.video == video)
        #expect(result.srt == srt)
    }

    @Test func srtWithoutVideoErrors() {
        let srt = URL(fileURLWithPath: "/v/clip.srt")
        #expect(throws: FilePairing.PairingError.videoNotFoundForSubtitles) {
            try pairer().resolve([srt])
        }
    }

    @Test func twoFilesPairedRegardlessOfName() throws {
        let video = URL(fileURLWithPath: "/v/movie.mov")
        let srt = URL(fileURLWithPath: "/x/notes.srt")
        let result = try pairer().resolve([video, srt])
        #expect(result.video == video)
        #expect(result.srt == srt)
    }

    @Test func twoVideosErrors() {
        let a = URL(fileURLWithPath: "/v/a.mp4")
        let b = URL(fileURLWithPath: "/v/b.mp4")
        #expect(throws: FilePairing.PairingError.tooManyVideos) {
            try pairer().resolve([a, b])
        }
    }

    @Test func noVideoOrSrtErrors() {
        let other = URL(fileURLWithPath: "/v/file.txt")
        #expect(throws: FilePairing.PairingError.noUsableFiles) {
            try pairer().resolve([other])
        }
    }
}
