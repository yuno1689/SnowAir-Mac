import Foundation

/// 标注撤销栈。只持有 AnnotationShape 快照，不触碰 CaptureResult.image。
public struct UndoStack<T> {
    private(set) var history: [T] = []
    private let limit: Int

    public init(limit: Int = 50) {
        self.limit = limit
    }

    public var canUndo: Bool { history.count > 1 }

    public mutating func record(_ state: T) {
        history.append(state)
        if history.count > limit { history.removeFirst() }
    }

    public mutating func undo() -> T? {
        guard history.count > 1 else { return nil }
        history.removeLast()
        return history.last
    }

    public mutating func reset(_ state: T) {
        history = [state]
    }
}
