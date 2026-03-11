import SwiftUI

enum CurveChannelKind: CaseIterable, Identifiable {
    case luma
    case red
    case green
    case blue

    var id: Self { self }

    var label: String {
        switch self {
        case .luma:
            return "Luma"
        case .red:
            return "Red"
        case .green:
            return "Green"
        case .blue:
            return "Blue"
        }
    }

    var shortLabel: String {
        switch self {
        case .luma:
            return "L"
        case .red:
            return "R"
        case .green:
            return "G"
        case .blue:
            return "B"
        }
    }

    var accentColor: Color {
        switch self {
        case .luma:
            return .orange
        case .red:
            return Color(red: 0.93, green: 0.34, blue: 0.28)
        case .green:
            return Color(red: 0.35, green: 0.82, blue: 0.40)
        case .blue:
            return Color(red: 0.32, green: 0.60, blue: 0.97)
        }
    }

    var settingsKeyPath: WritableKeyPath<AdjustmentSettings, CurvePointSet> {
        switch self {
        case .luma:
            return \.color.curves.luma
        case .red:
            return \.color.curves.red
        case .green:
            return \.color.curves.green
        case .blue:
            return \.color.curves.blue
        }
    }
}

struct CurveChannelTabs: View {
    @Binding var selection: CurveChannelKind
    var usesShortLabels = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(CurveChannelKind.allCases) { channel in
                let isSelected = selection == channel

                Button {
                    selection = channel
                } label: {
                    Text(usesShortLabels ? channel.shortLabel : channel.label)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(isSelected ? channel.accentColor.opacity(0.22) : Color.white.opacity(0.04))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(
                                    isSelected ? channel.accentColor.opacity(0.9) : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CurveEditorView: View {
    let title: String?
    @Binding var curve: CurvePointSet
    var accentColor: Color = .orange
    var compact = false
    private var handleDiameter: CGFloat { compact ? 11 : 13 }
    private var plotInsetX: CGFloat { compact ? 8 : 12 }
    private var plotInsetY: CGFloat { compact ? 7 : 10 }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            if let title {
                Text(title)
                    .font(compact ? .caption : .headline)
                    .fontWeight(.semibold)
            }

            GeometryReader { geometry in
                let plotRect = plotRect(in: geometry.size)

                ZStack {
                    RoundedRectangle(cornerRadius: compact ? 10 : 12)
                        .fill(.black.opacity(0.18))

                    grid(in: plotRect)
                        .stroke(.white.opacity(0.08), lineWidth: 1)

                    curvePath(in: plotRect)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))

                    ForEach(Array(curve.values.enumerated()), id: \.offset) { index, value in
                        Circle()
                            .fill(Color.white)
                            .frame(width: handleDiameter, height: handleDiameter)
                            .overlay {
                                Circle().stroke(accentColor, lineWidth: compact ? 1.4 : 2)
                            }
                            .position(pointPosition(index: index, value: value, rect: plotRect))
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateCurve(at: value.location, rect: plotRect)
                        }
                )
            }
            .frame(height: compact ? 72 : 148)
        }
    }

    private func plotRect(in size: CGSize) -> CGRect {
        CGRect(
            x: plotInsetX,
            y: plotInsetY,
            width: max(size.width - plotInsetX * 2, 1),
            height: max(size.height - plotInsetY * 2, 1)
        )
    }

    private func grid(in rect: CGRect) -> Path {
        Path { path in
            for index in 0..<5 {
                let ratio = CGFloat(index) / 4
                let x = rect.minX + rect.width * ratio
                let y = rect.minY + rect.height * ratio
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        }
    }

    private func curvePath(in rect: CGRect) -> Path {
        Path { path in
            for index in curve.values.indices {
                let point = pointPosition(index: index, value: curve.values[index], rect: rect)
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }

    private func pointPosition(index: Int, value: Double, rect: CGRect) -> CGPoint {
        let x = rect.minX + CGFloat(index) / 4 * rect.width
        let y = rect.minY + (1 - CGFloat(value)) * rect.height
        return CGPoint(x: x, y: y)
    }

    private func updateCurve(at location: CGPoint, rect: CGRect) {
        let clampedX = location.x.clamped(to: rect.minX...rect.maxX)
        let clampedY = location.y.clamped(to: rect.minY...rect.maxY)
        let normalizedX = ((clampedX - rect.minX) / max(rect.width, 1)).clamped(to: 0...1)
        let closestIndex = Int((normalizedX * 4).rounded()).clamped(to: 0...4)
        let normalizedY = (1 - (clampedY - rect.minY) / max(rect.height, 1)).clamped(to: 0...1)

        var updated = curve
        updated[closestIndex] = normalizedY
        curve = updated
    }
}
