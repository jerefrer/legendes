public struct UndoStack<State>: Sendable where State: Sendable {
    private var past: [State] = []
    private var future: [State] = []
    private let maxDepth: Int

    public init(maxDepth: Int = 100) {
        self.maxDepth = max(1, maxDepth)
    }

    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }

    /// Record the state that existed BEFORE an edit. Clears the redo future.
    public mutating func record(_ preEditState: State) {
        past.append(preEditState)
        if past.count > maxDepth { past.removeFirst(past.count - maxDepth) }
        future.removeAll()
    }

    /// Restore the previous state. `current` is the live state, kept for redo.
    public mutating func undo(current: State) -> State? {
        guard let previous = past.popLast() else { return nil }
        future.append(current)
        return previous
    }

    /// Re-apply a previously undone state. `current` is kept for undo.
    public mutating func redo(current: State) -> State? {
        guard let next = future.popLast() else { return nil }
        past.append(current)
        return next
    }
}
