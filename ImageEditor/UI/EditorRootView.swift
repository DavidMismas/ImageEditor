import SwiftUI

struct EditorRootView: View {
    @StateObject private var viewModel = EditorViewModel()
    @State private var showsExportSheet = false

    var body: some View {
        HSplitView {
            MediaLibraryView(viewModel: viewModel)
                .frame(minWidth: 270, idealWidth: 285, maxWidth: 340)

            inspectorSidebar
                .frame(minWidth: 270, idealWidth: 285, maxWidth: 340)

            VStack(spacing: 0) {
                toolbar

                ZStack(alignment: .bottomTrailing) {
                    PreviewCanvasView(
                        primaryImage: viewModel.previewImage,
                        comparisonImage: viewModel.comparisonImage,
                        mode: viewModel.previewMode,
                        zoomScale: viewModel.zoomScale,
                        fitToScreen: viewModel.fitToScreen,
                        isRendering: viewModel.isRendering,
                        onSizeChange: viewModel.setPreviewSize
                    )

                    HistogramView(histogram: viewModel.histogram)
                        .frame(width: 270)
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .padding(16)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.11, blue: 0.14), Color(red: 0.07, green: 0.08, blue: 0.11)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .sheet(isPresented: $showsExportSheet) {
            ExportSettingsSheet(viewModel: viewModel, isPresented: $showsExportSheet)
        }
        .overlay(alignment: .bottomTrailing) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(.caption, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(16)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.selectedDocument?.title ?? "Preview")
                    .font(.system(.title3, design: .serif, weight: .bold))
                Text(viewModel.selectedDocument?.asset.isRAW == true ? "RAW selected" : "Editing workspace")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 20)

            Picker("Preview", selection: $viewModel.previewMode) {
                ForEach(PreviewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 230)

            Spacer(minLength: 20)

            Divider()
                .frame(height: 18)

            Button("Reset", action: viewModel.resetAdjustments)
                .disabled(viewModel.selectedDocument == nil)
            Button("Copy", action: viewModel.copyAdjustments)
                .disabled(viewModel.selectedDocument == nil)
            Button("Paste", action: viewModel.pasteAdjustments)
                .disabled(viewModel.selectedDocument == nil)

            Divider()
                .frame(height: 18)

            Button("Fit", action: viewModel.fitPreview)
            Button("100%", action: viewModel.zoomToActualPixels)
            Slider(value: $viewModel.zoomScale, in: 0.25...3)
                .frame(width: 110)

            Divider()
                .frame(height: 18)

            Button("Export") {
                showsExportSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(viewModel.selectedDocument == nil)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    @ViewBuilder
    private var inspectorSidebar: some View {
        if let document = viewModel.selectedDocument {
            EditingSidebarView(
                document: document,
                luts: viewModel.importedLUTs,
                onImportLUT: viewModel.importLUT
            )
        } else {
            VStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Select an image to edit")
                    .font(.system(.title3, design: .serif, weight: .bold))
                Text("The left tool column appears once an image is selected.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.11, green: 0.12, blue: 0.15), Color(red: 0.08, green: 0.09, blue: 0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}
