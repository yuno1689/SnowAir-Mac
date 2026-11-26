import Foundation

/// 标注撤销栈。只持有 AnnotationShape 快照，不触碰 CaptureResult.image。
struct UndoStack<T> {
    private(set) var history: [T] = []
    private let limit: Int

    init(limit: Int = 50) {
        self.limit = limit
    }

    var canUndo: Bool { history.count > 1 }

    mutating func record(_ state: T) {
        history.append(state)
        if history.count > limit { history.removeFirst() }
    }

    mutating func undo() -> T? {
        guard history.count > 1 else { return nil }
        history.removeLast()
        return history.last
    }

    mutating func reset(_ state: T) {
        history = [state]
    }
}
