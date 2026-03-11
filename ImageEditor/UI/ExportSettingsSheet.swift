import SwiftUI

struct ExportSettingsSheet: View {
    @ObservedObject var viewModel: EditorViewModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Format and color settings live here, not in the main toolbar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                pickerRow(title: "Format") {
                    Picker("Format", selection: $viewModel.exportFormat) {
                        ForEach(ExportFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                pickerRow(title: "Color Space") {
                    Picker("Color Space", selection: $viewModel.outputColorSpace) {
                        ForEach(OutputColorSpaceOption.allCases) { colorSpace in
                            Text(colorSpace.rawValue).tag(colorSpace)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                if viewModel.exportFormat == .jpeg {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("JPEG Quality")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.0f", viewModel.jpegQuality))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $viewModel.jpegQuality, in: 0...100)
                            .tint(.orange)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Export") {
                    isPresented = false
                    DispatchQueue.main.async {
                        viewModel.exportSelectedImage()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.selectedDocument == nil)
            }
        }
        .padding(22)
        .frame(width: 360, height: 280)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.13, blue: 0.16), Color(red: 0.08, green: 0.09, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func pickerRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            content()
        }
    }
}
