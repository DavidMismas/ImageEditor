import SwiftUI

struct CropPanelView: View {
    @ObservedObject var document: PhotoDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Crop & Geometry")
                    .font(.system(.title3, design: .serif, weight: .bold))

                Picker("Aspect", selection: document.binding(for: \.crop.aspectPreset)) {
                    ForEach(CropAspectPreset.allCases) { preset in
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
                AdjustmentSlider(title: "Crop Zoom", value: document.binding(for: \.crop.zoom), range: 1...5, format: "%.2f")
                AdjustmentSlider(title: "Horizontal", value: document.binding(for: \.crop.centerX), range: 0...1, format: "%.2f")
                AdjustmentSlider(title: "Vertical", value: document.binding(for: \.crop.centerY), range: 0...1, format: "%.2f")

                if document.settings.crop.aspectPreset == .free {
                    Divider().padding(.vertical, 2)
                    AdjustmentSlider(title: "Width", value: document.binding(for: \.crop.freeformWidth), range: 0.2...1, format: "%.2f")
                    AdjustmentSlider(title: "Height", value: document.binding(for: \.crop.freeformHeight), range: 0.2...1, format: "%.2f")
                }
            }
            .padding(18)
        }
    }
}
