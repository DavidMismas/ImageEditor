import SwiftUI

struct EffectsPanelView: View {
    @ObservedObject var document: PhotoDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Effects")
                    .font(.title3)
                    .fontWeight(.bold)

                AdjustmentSlider(title: "Clarity", value: document.binding(for: \.effects.clarity), range: -100...100)
                AdjustmentSlider(title: "Sharpness", value: document.binding(for: \.effects.sharpness), range: 0...100)
                AdjustmentSlider(title: "Grain", value: document.binding(for: \.effects.grain), range: 0...100)
                AdjustmentSlider(title: "Vignette", value: document.binding(for: \.effects.vignette), range: 0...100)
            }
            .padding(18)
        }
    }
}
