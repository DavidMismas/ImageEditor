@preconcurrency import AppKit
import SwiftUI

struct MediaLibraryView: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Media Library")
                        .font(.system(.title3, design: .serif, weight: .bold))
                    Text("\(viewModel.documents.count) imported")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Import", action: viewModel.importImages)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
            .padding(16)
            .background(.thinMaterial)

            List(selection: $viewModel.selectedDocumentID) {
                ForEach(viewModel.documents) { document in
                    MediaLibraryRow(document: document)
                        .tag(document.id)
                }
            }
            .listStyle(.sidebar)
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.14, green: 0.15, blue: 0.18), Color(red: 0.10, green: 0.11, blue: 0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct MediaLibraryRow: View {
    @ObservedObject var document: PhotoDocument

    var body: some View {
        HStack(spacing: 12) {
            if let thumbnail = document.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.08))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .lineLimit(1)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))

                Text(document.asset.isRAW ? "RAW" : "Standard")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(document.asset.isRAW ? .orange : .secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
