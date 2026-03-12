import SwiftUI

struct EditingSidebarView: View {
    @ObservedObject var document: PhotoDocument
    let luts: [LUTPreset]
    let onImportLUT: () -> Void
    let isCropOverlayActive: Bool
    let onToggleCropOverlay: () -> Void

    @State private var selectedChannel: HSLChannelKind = .orange
    @State private var cropExpanded = true
    @State private var lightExpanded = true
    @State private var balanceExpanded = true
    @State private var gradingExpanded = true
    @State private var hslExpanded = false
    @State private var curvesExpanded = false
    @State private var selectedCurveChannel: CurveChannelKind = .luma
    @State private var effectsExpanded = false
    @State private var lutExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Adjustments")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(document.asset.isRAW ? "RAW workflow" : "Pixel workflow")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                InspectorSection(
                    title: "Crop & Geometry",
                    subtitle: "Frame and orient the shot first.",
                    isExpanded: $cropExpanded,
                    onReset: {
                        document.updateSettings { $0.crop = CropSettings() }
                    }
                ) {
                    cropControls
                }

                InspectorSection(
                    title: "Light",
                    subtitle: "Primary tonal structure.",
                    isExpanded: $lightExpanded,
                    onReset: {
                        document.updateSettings {
                            $0.base.exposure = BaseAdjustments().exposure
                            $0.base.contrast = BaseAdjustments().contrast
                            $0.base.highlights = BaseAdjustments().highlights
                            $0.base.shadows = BaseAdjustments().shadows
                            $0.base.whites = BaseAdjustments().whites
                            $0.base.blacks = BaseAdjustments().blacks
                        }
                    }
                ) {
                    lightControls
                }

                InspectorSection(
                    title: "White Balance",
                    subtitle: "Color temperature, presence, and RAW decode.",
                    isExpanded: $balanceExpanded,
                    onReset: {
                        let defaults = BaseAdjustments()
                        document.updateSettings {
                            $0.base.temperature = defaults.temperature
                            $0.base.tint = defaults.tint
                            $0.base.vibrance = defaults.vibrance
                            $0.base.saturation = defaults.saturation
                        }
                    }
                ) {
                    balanceControls
                }

                InspectorSection(
                    title: "Color Grading",
                    subtitle: "Global, shadows, and highlights.",
                    isExpanded: $gradingExpanded,
                    onReset: {
                        document.updateSettings { $0.color.grading = ColorGradingSettings() }
                    }
                ) {
                    gradingControls
                }

                InspectorSection(
                    title: "HSL",
                    subtitle: "Target one hue family at a time.",
                    isExpanded: $hslExpanded,
                    onReset: {
                        document.updateSettings { $0.color.hsl = HSLSettings() }
                    }
                ) {
                    hslControls
                }

                InspectorSection(
                    title: "Curves",
                    subtitle: "Shape one channel at a time.",
                    isExpanded: $curvesExpanded,
                    onReset: {
                        document.updateSettings { $0.color.curves = ColorCurveSettings() }
                    }
                ) {
                    curveControls
                }

                InspectorSection(
                    title: "Effects",
                    subtitle: "Structure and finish.",
                    isExpanded: $effectsExpanded,
                    onReset: {
                        document.updateSettings { $0.effects = EffectsSettings() }
                    }
                ) {
                    effectsControls
                }

                InspectorSection(
                    title: "LUT",
                    subtitle: "Import and blend creative looks.",
                    isExpanded: $lutExpanded,
                    onReset: {
                        document.updateSettings { $0.lut = LUTSelection() }
                    }
                ) {
                    lutControls
                }
            }
            .padding(12)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.12, blue: 0.15), Color(red: 0.08, green: 0.09, blue: 0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var cropControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(isCropOverlayActive ? "Done Crop" : "Edit Crop on Canvas", action: onToggleCropOverlay)
                .buttonStyle(.borderedProminent)
                .tint(isCropOverlayActive ? .white.opacity(0.24) : .orange)
                .foregroundStyle(.white)
                .controlSize(.small)

            compactMenu("Aspect", selection: document.binding(for: \.crop.aspectPreset)) {
                ForEach(CropAspectPreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }

            HStack(spacing: 8) {
                Button("Left") {
                    document.updateSettings { $0.crop.rotationQuarterTurns -= 1 }
                }
                Button("Right") {
                    document.updateSettings { $0.crop.rotationQuarterTurns += 1 }
                }
                Toggle("Flip H", isOn: document.binding(for: \.crop.flipHorizontal))
                    .toggleStyle(.button)
                Toggle("Flip V", isOn: document.binding(for: \.crop.flipVertical))
                    .toggleStyle(.button)
            }
            .controlSize(.small)

            AdjustmentSlider(title: "Straighten", value: document.binding(for: \.crop.straighten), range: -45...45, format: "%.1f")
            Text("Drag edges and corners directly on the preview.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var lightControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdjustmentSlider(title: "Exposure", value: document.binding(for: \.base.exposure), range: -5...5, format: "%.2f")
            AdjustmentSlider(title: "Contrast", value: document.binding(for: \.base.contrast), range: -100...100)
            AdjustmentSlider(title: "Highlights", value: document.binding(for: \.base.highlights), range: -100...100)
            AdjustmentSlider(title: "Shadows", value: document.binding(for: \.base.shadows), range: -100...100)
            AdjustmentSlider(title: "Whites", value: document.binding(for: \.base.whites), range: -100...100)
            AdjustmentSlider(title: "Blacks", value: document.binding(for: \.base.blacks), range: -100...100)
        }
    }

    private var balanceControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdjustmentSlider(title: "Temperature", value: document.binding(for: \.base.temperature), range: -100...100)
            AdjustmentSlider(title: "Tint", value: document.binding(for: \.base.tint), range: -100...100)
            AdjustmentSlider(title: "Vibrance", value: document.binding(for: \.base.vibrance), range: -100...100)
            AdjustmentSlider(title: "Saturation", value: document.binding(for: \.base.saturation), range: -100...100)
        }
    }

    private var gradingControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            gradingSliders(
                title: "Global",
                hue: \.color.grading.global.hue,
                value: \.color.grading.global.intensity
            )
            gradingSliders(
                title: "Shadows",
                hue: \.color.grading.shadows.hue,
                value: \.color.grading.shadows.intensity
            )
            gradingSliders(
                title: "Highlights",
                hue: \.color.grading.highlights.hue,
                value: \.color.grading.highlights.intensity
            )
        }
    }

    private var hslControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            compactMenu("Channel", selection: $selectedChannel) {
                ForEach(HSLChannelKind.allCases) { channel in
                    Text(channel.rawValue).tag(channel)
                }
            }

            HSLHueAdjustmentSlider(title: "Hue", channel: selectedChannel, value: hslBinding(\.hue))
            AdjustmentSlider(title: "Saturation", value: hslBinding(\.saturation), range: -100...100)
            AdjustmentSlider(title: "Luminance", value: hslBinding(\.luminance), range: -100...100)
        }
    }

    private var curveControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            CurveChannelTabs(selection: $selectedCurveChannel, usesShortLabels: true)
            CurveEditorView(
                title: nil,
                curve: document.binding(for: selectedCurveChannel.settingsKeyPath),
                accentColor: selectedCurveChannel.accentColor
            )
        }
    }

    private var effectsControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            AdjustmentSlider(title: "Clarity", value: document.binding(for: \.effects.clarity), range: -100...100)
            AdjustmentSlider(title: "Sharpness", value: document.binding(for: \.effects.sharpness), range: 0...100)
            AdjustmentSlider(title: "Grain", value: document.binding(for: \.effects.grain), range: 0...100)
            AdjustmentSlider(title: "Vignette", value: document.binding(for: \.effects.vignette), range: 0...100)
        }
    }

    private var lutControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Creative look")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Import .cube", action: onImportLUT)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .controlSize(.small)
            }

            compactMenu("Look", selection: document.binding(for: \.lut.selectedLUTID)) {
                Text("None").tag(Optional<UUID>.none)
                ForEach(luts) { lut in
                    Text(lut.name).tag(Optional(lut.id))
                }
            }

            AdjustmentSlider(title: "Intensity", value: document.binding(for: \.lut.intensity), range: 0...100)

            if !luts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(luts) { lut in
                        HStack(spacing: 8) {
                            Text(lut.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Spacer()
                            Text("\(lut.dimension)^3")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 2)
            }
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
    }

    private func compactMenu<SelectionValue: Hashable, Content: View>(
        _ title: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection, content: content)
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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

private struct InspectorSection<Content: View>: View {
    let title: String
    let subtitle: String
    @Binding var isExpanded: Bool
    let onReset: (() -> Void)?
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String,
        isExpanded: Binding<Bool>,
        onReset: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        _isExpanded = isExpanded
        self.onReset = onReset
        self.content = content()
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(.top, 12)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if let onReset {
                    Button("Reset", action: onReset)
                        .font(.caption2)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(.white)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
    }
}
