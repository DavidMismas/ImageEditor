import SwiftUI

struct CropPanelView: View {
    @ObservedObject var document: PhotoDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Crop & Geometry")
                    .font(.title3)
                    .fontWeight(.bold)

                Picker("Aspect", selection: document.binding(for: \.crop.aspectPreset)) {
                    ForEach(CropAspectPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)

                Picker("Overlay", selection: document.binding(for: \.crop.overlay)) {
                    ForEach(CropOverlayPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)

                HStack(spacing: 10) {
                    Button("Rotate Left") {
                        document.updateSettings { $0.crop.rotationQuarterTurns -= 1 }
                    }
                    Button("Rotate Right") {
                        document.updateSettings { $0.crop.rotationQuarterTurns += 1 }
                    }
                    Toggle("Flip H", isOn: document.binding(for: \.crop.flipHorizontal))
                    Toggle("Flip V", isOn: document.binding(for: \.crop.flipVertical))
                }

                AdjustmentSlider(title: "Straighten", value: document.binding(for: \.crop.straighten), range: -45...45, format: "%.1f")
                Text("Use the crop overlay on the canvas to resize and move the crop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        }
    }
}
