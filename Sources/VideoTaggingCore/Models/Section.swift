import Foundation

public struct Section: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var start: Int   // milliseconds
    public var end: Int     // milliseconds
    public var text: String

    public init(id: UUID = UUID(), start: Int, end: Int, text: String = "") {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    public var durationMs: Int { end - start }
}
