import SwiftUI

struct BasePanelView: View {
    @ObservedObject var document: PhotoDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Primary Corrections")
                    .font(.title3)
                    .fontWeight(.bold)

                AdjustmentSlider(title: "Exposure", value: document.binding(for: \.base.exposure), range: -5...5, format: "%.2f")
                AdjustmentSlider(title: "Contrast", value: document.binding(for: \.base.contrast), range: -100...100)
                AdjustmentSlider(title: "Highlights", value: document.binding(for: \.base.highlights), range: -100...100)
                AdjustmentSlider(title: "Shadows", value: document.binding(for: \.base.shadows), range: -100...100)
                AdjustmentSlider(title: "Whites", value: document.binding(for: \.base.whites), range: -100...100)
                AdjustmentSlider(title: "Blacks", value: document.binding(for: \.base.blacks), range: -100...100)

                Divider().padding(.vertical, 2)

                Text("Color Balance")
                    .font(.headline)
                    .fontWeight(.semibold)

                AdjustmentSlider(title: "Temperature", value: document.binding(for: \.base.temperature), range: -100...100)
                AdjustmentSlider(title: "Tint", value: document.binding(for: \.base.tint), range: -100...100)
                AdjustmentSlider(title: "Vibrance", value: document.binding(for: \.base.vibrance), range: -100...100)
                AdjustmentSlider(title: "Saturation", value: document.binding(for: \.base.saturation), range: -100...100)
            }
            .padding(18)
        }
    }
}
