public struct EditorSnapshot: Equatable, Sendable {
    public var sections: [Section]
    public var currentIndex: Int
    public init(sections: [Section], currentIndex: Int) {
        self.sections = sections
        self.currentIndex = currentIndex
    }
}
