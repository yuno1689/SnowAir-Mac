import SnowAirCore
import SwiftUI

struct ToolbarView: View {
    @Binding var tool: ShapeKind
    @Binding var style: StrokeStyle

    private let columns = Array(ShapeKind.allCases)

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(columns, id: \.self) { kind in
                    Button {
                        tool = kind
                    } label: {
                        Text(kind.displayName)
                            .font(.system(size: 11))
                            .frame(width: 46, height: 26)
                            .background(tool == kind ? Color.accentColor.opacity(0.25) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                ForEach(Array([RGBA.red, .yellow, .green, .blue, .white].enumerated()), id: \.offset) { _, color in
                    Button {
                        style.color = color
                    } label: {
                        Circle()
                            .fill(Color(red: color.r, green: color.g, blue: color.b))
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle().stroke(style.color == color ? Color.primary : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Slider(value: $style.width, in: 1...20, step: 1)
                    .frame(width: 100)

                Text("\(Int(style.width))")
                    .font(.system(size: 11))
                    .frame(width: 20)
            }
        }
    }
}
