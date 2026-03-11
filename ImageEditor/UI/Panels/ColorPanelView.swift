import SwiftUI

struct ColorPanelView: View {
    @ObservedObject var document: PhotoDocument
    @State private var selectedChannel: HSLChannelKind = .red
    @State private var selectedCurveChannel: CurveChannelKind = .luma

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Color Grading")
                    .font(.title3)
                    .fontWeight(.bold)

                HStack(alignment: .top, spacing: 18) {
                    gradingSliders(title: "Global", hue: \.color.grading.global.hue, value: \.color.grading.global.intensity)
                    gradingSliders(title: "Shadows", hue: \.color.grading.shadows.hue, value: \.color.grading.shadows.intensity)
                    gradingSliders(title: "Highlights", hue: \.color.grading.highlights.hue, value: \.color.grading.highlights.intensity)
                }

                Divider()

                Text("HSL")
                    .font(.headline)
                    .fontWeight(.semibold)

                Picker("Channel", selection: $selectedChannel) {
                    ForEach(HSLChannelKind.allCases) { channel in
                        Text(channel.rawValue).tag(channel)
                    }
                }
                .pickerStyle(.segmented)

                HSLHueAdjustmentSlider(title: "Hue", channel: selectedChannel, value: hslBinding(\.hue))
                AdjustmentSlider(title: "Saturation", value: hslBinding(\.saturation), range: -100...100)
                AdjustmentSlider(title: "Luminance", value: hslBinding(\.luminance), range: -100...100)

                Divider()

                Text("Tone Curves")
                    .font(.headline)
                    .fontWeight(.semibold)

                CurveChannelTabs(selection: $selectedCurveChannel)
                CurveEditorView(
                    title: "\(selectedCurveChannel.label) Curve",
                    curve: document.binding(for: selectedCurveChannel.settingsKeyPath),
                    accentColor: selectedCurveChannel.accentColor
                )
            }
            .padding(18)
        }
    }

    private func gradingSliders(
        title: String,
        hue: WritableKeyPath<AdjustmentSettings, Double>,
        value: WritableKeyPath<AdjustmentSettings, Double>
    ) -> some View {
        ColorGradingSliders(
            title: title,
            hue: document.binding(for: hue),
            value: document.binding(for: value)
        )
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
