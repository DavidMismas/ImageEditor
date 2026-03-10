import SwiftUI

struct ColorPanelView: View {
    @ObservedObject var document: PhotoDocument
    @State private var selectedChannel: HSLChannelKind = .red

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Color Grading")
                    .font(.system(.title3, design: .serif, weight: .bold))

                HStack(alignment: .top, spacing: 18) {
                    wheel(title: "Global", hue: \.color.grading.global.hue, intensity: \.color.grading.global.intensity, luminance: \.color.grading.global.luminance)
                    wheel(title: "Shadows", hue: \.color.grading.shadows.hue, intensity: \.color.grading.shadows.intensity, luminance: \.color.grading.shadows.luminance)
                    wheel(title: "Highlights", hue: \.color.grading.highlights.hue, intensity: \.color.grading.highlights.intensity, luminance: \.color.grading.highlights.luminance)
                }

                Divider()

                Text("HSL")
                    .font(.system(.headline, design: .rounded, weight: .semibold))

                Picker("Channel", selection: $selectedChannel) {
                    ForEach(HSLChannelKind.allCases) { channel in
                        Text(channel.rawValue).tag(channel)
                    }
                }
                .pickerStyle(.segmented)

                AdjustmentSlider(title: "Hue", value: hslBinding(\.hue), range: -100...100)
                AdjustmentSlider(title: "Saturation", value: hslBinding(\.saturation), range: -100...100)
                AdjustmentSlider(title: "Luminance", value: hslBinding(\.luminance), range: -100...100)

                Divider()

                Text("Tone Curves")
                    .font(.system(.headline, design: .rounded, weight: .semibold))

                CurveEditorView(title: "Luma Curve", curve: document.binding(for: \.color.curves.luma))
                CurveEditorView(title: "Red Curve", curve: document.binding(for: \.color.curves.red))
                CurveEditorView(title: "Green Curve", curve: document.binding(for: \.color.curves.green))
                CurveEditorView(title: "Blue Curve", curve: document.binding(for: \.color.curves.blue))
            }
            .padding(18)
        }
    }

    private func wheel(
        title: String,
        hue: WritableKeyPath<AdjustmentSettings, Double>,
        intensity: WritableKeyPath<AdjustmentSettings, Double>,
        luminance: WritableKeyPath<AdjustmentSettings, Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ColorWheelControl(
                title: title,
                hue: document.binding(for: hue),
                intensity: document.binding(for: intensity)
            )
            AdjustmentSlider(title: "Luminance", value: document.binding(for: luminance), range: -100...100)
        }
        .frame(maxWidth: .infinity)
    }

    private func hslBinding(_ keyPath: WritableKeyPath<HSLChannelAdjustment, Double>) -> Binding<Double> {
        Binding(
            get: {
                document.settings.color.hsl[selectedChannel][keyPath: keyPath]
            },
            set: { newValue in
                document.updateSettings { settings in
                    var channel = settings.color.hsl[selectedChannel]
                    channel[keyPath: keyPath] = newValue
                    settings.color.hsl[selectedChannel] = channel
                }
            }
        )
    }
}
