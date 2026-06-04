import Testing
@testable import VideoTaggingCore

@Suite struct UndoStackTests {
    @Test func startsEmpty() {
        let s = UndoStack<Int>(maxDepth: 10)
        #expect(!s.canUndo)
        #expect(!s.canRedo)
    }

    @Test func recordEnablesUndo() {
        var s = UndoStack<Int>(maxDepth: 10)
        s.record(1)            // pre-edit state was 1
        #expect(s.canUndo)
        #expect(!s.canRedo)
    }

    @Test func undoReturnsPreviousAndEnablesRedo() {
        var s = UndoStack<Int>(maxDepth: 10)
        s.record(1)            // state was 1, then live became 2
        let restored = s.undo(current: 2)
        #expect(restored == 1)
        #expect(!s.canUndo)
        #expect(s.canRedo)
    }

    @Test func redoReturnsForwardState() {
        var s = UndoStack<Int>(maxDepth: 10)
        s.record(1)
        _ = s.undo(current: 2)     // back to 1
        let redone = s.redo(current: 1)
        #expect(redone == 2)
        #expect(s.canUndo)
        #expect(!s.canRedo)
    }

    @Test func recordClearsRedoFuture() {
        var s = UndoStack<Int>(maxDepth: 10)
        s.record(1)
        _ = s.undo(current: 2)     // canRedo == true
        s.record(1)                // a new edit clears redo
        #expect(!s.canRedo)
    }

    @Test func undoOnEmptyReturnsNil() {
        var s = UndoStack<Int>(maxDepth: 10)
        #expect(s.undo(current: 5) == nil)
    }

    @Test func boundedDepthEvictsOldest() {
        var s = UndoStack<Int>(maxDepth: 2)
        s.record(1); s.record(2); s.record(3)   // only 2 and 3 retained
        #expect(s.undo(current: 99) == 3)
        #expect(s.undo(current: 3) == 2)
        #expect(!s.canUndo)                      // 1 was evicted
    }
}
