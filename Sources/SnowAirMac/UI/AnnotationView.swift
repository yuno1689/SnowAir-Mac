import AppKit
import SnowAirCore
import SwiftUI

struct AnnotationView: View {
    let result: CaptureResult
    let config: AppConfig
    let onFinish: () -> Void

    @State private var shapes: [AnnotationShape] = []
    @State private var draft: AnnotationShape?
    @State private var currentTool: ShapeKind = .rectangle
    @State private var style: StrokeStyle = .default
    @State private var undo = UndoStack<[AnnotationShape]>()
    @State private var showTextInput = false
    @State private var pendingText = ""

    init(result: CaptureResult, config: AppConfig, onFinish: @escaping () -> Void) {
        self.result = result
        self.config = config
        self.onFinish = onFinish
        // 用 State(wrappedValue:) 显式构造，规避 Swift 6 对 _style 直接赋值的推断问题
        self.style = StrokeStyle(color: config.strokeColor, width: config.strokeWidth)
        self.currentTool = config.defaultTool
    }

    var body: some View {
        ZStack(alignment: .top) {
            AnnotationCanvas(
                image: result.image,
                shapes: shapes,
                draft: draft,
                tool: currentTool,
                onStart: { p in startShape(at: p) },
                onMove: { p in moveShape(to: p) },
                onEnd: { p in endShape(at: p) }
            )

            ToolbarView(tool: $currentTool, style: $style)
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 12)
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 12) {
                Button("撤销") { if let s = undo.undo() { shapes = s } }
                    .disabled(!undo.canUndo)
                Button("清空") { record([]); shapes = [] }
                Button("完成") { finish() }
                    .keyboardShortcut(.return, modifiers: [])
                Button("取消") { onFinish() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $showTextInput) {
            textInputSheet
        }
        .onAppear { undo.reset([]) }
    }

    // MARK: - 交互

    private func startShape(at p: CGPoint) {
        let style = self.style
        switch currentTool {
        case .text:
            // 记录插入点但暂不生成 draft，等文本提交时一次性构造
            pendingText = ""
            draft = AnnotationShape(kind: ShapeKind.text, points: [p], style: style, text: nil)
            showTextInput = true
        case .number:
            let n = (shapes.compactMap { $0.number }.max() ?? 0) + 1
            let s = AnnotationShape(kind: ShapeKind.number, points: [p], style: style, number: n)
            draft = s
        default:
            draft = AnnotationShape(kind: currentTool, points: [p, p], style: style)
        }
    }

    private func updatedDraft(at p: CGPoint) -> AnnotationShape? {
        guard var d = draft, !d.points.isEmpty else { return nil }
        if currentTool == ShapeKind.pen {
            d.points.append(p)
        } else {
            // 两点工具：索引 1 恒存在（startShape 以 [p, p] 初始化）
            if d.points.count == 1 { d.points.append(p) }
            else { d.points[1] = p }
        }
        return d
    }

    private func moveShape(to p: CGPoint) {
        if let d = updatedDraft(at: p) { draft = d }
    }

    private func endShape(at p: CGPoint) {
        // 不依赖 @State 即时回读：基于当前 draft 计算最终图形
        let final = updatedDraft(at: p)
        if let d = final, d.isValid {
            shapes.append(d)
            record(shapes)
        }
        draft = nil
    }

    private func commitText(_ text: String, at point: CGPoint) {
        guard !text.isEmpty else { return }
        let s = AnnotationShape(
            kind: ShapeKind.text, points: [point], style: style,
            text: text, fontSize: 18
        )
        record(shapes + [s])
        shapes.append(s)
    }

    private func record(_ state: [AnnotationShape]) {
        undo.record(state)
    }

    private func finish() {
        guard let final = ImageExporter.composite(image: result.image, shapes: shapes) else { return }
        CaptureCoordinator.export(result, shapes: shapes, compositedImage: final)
        onFinish()
    }

    private var textInputSheet: some View {
        VStack(spacing: 12) {
            Text("输入标注文字").font(.headline)
            TextField("文字", text: $pendingText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            HStack {
                Button("取消") { showTextInput = false }
                Button("确定") {
                    if let p = draft?.points.first { commitText(pendingText, at: p) }
                    draft = nil
                    showTextInput = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
