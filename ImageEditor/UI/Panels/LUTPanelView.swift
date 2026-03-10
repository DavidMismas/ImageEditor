import SwiftUI

struct LUTPanelView: View {
    @ObservedObject var document: PhotoDocument
    let luts: [LUTPreset]
    let onImport: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("LUT")
                        .font(.system(.title3, design: .serif, weight: .bold))
                    Spacer()
                    Button("Import .cube", action: onImport)
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                }

                Picker("Look", selection: document.binding(for: \.lut.selectedLUTID)) {
                    Text("None").tag(Optional<UUID>.none)
                    ForEach(luts) { lut in
                        Text(lut.name).tag(Optional(lut.id))
                    }
                }
                .pickerStyle(.menu)

                AdjustmentSlider(title: "Intensity", value: document.binding(for: \.lut.intensity), range: 0...100)

                if luts.isEmpty {
                    Text("Imported LUTs will appear here. Only 3D `.cube` files are supported.")
                        .foregroundStyle(.secondary)
                        .font(.system(.subheadline, design: .rounded))
                        .padding(.top, 8)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Library")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                        ForEach(luts) { lut in
                            HStack {
                                Text(lut.name)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(lut.dimension)^3")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
            }
            .padding(18)
        }
    }
}
