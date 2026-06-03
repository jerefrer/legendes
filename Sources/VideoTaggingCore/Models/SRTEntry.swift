public struct SRTEntry: Equatable, Sendable {
    public var start: Int   // milliseconds
    public var end: Int     // milliseconds
    public var text: String
    public init(start: Int, end: Int, text: String) {
        self.start = start
        self.end = end
        self.text = text
    }
}
