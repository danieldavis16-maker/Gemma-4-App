import SwiftUI
import UniformTypeIdentifiers

struct DocumentsSheet: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.loadedDocuments.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "doc.text",
                        description: Text("Upload PDF, TXT, or Markdown files to give Gemma domain knowledge.")
                    )
                } else {
                    ForEach(viewModel.loadedDocuments) { doc in
                        HStack {
                            Image(systemName: iconForFilename(doc.filename))
                                .foregroundColor(.purple)
                            VStack(alignment: .leading) {
                                Text(doc.filename)
                                    .font(.body)
                                Text("\(doc.chunkCount) chunks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteDocument(filename: viewModel.loadedDocuments[index].filename)
                        }
                    }
                }
            }
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        viewModel.showDocumentsSheet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporting = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.pdf, .plainText, .init(filenameExtension: "md")].compactMap { $0 },
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: url) {
                        viewModel.uploadDocument(data: data, filename: url.lastPathComponent)
                    }
                case .failure:
                    break
                }
            }
            .onAppear {
                viewModel.refreshDocuments()
            }
        }
    }

    private func iconForFilename(_ name: String) -> String {
        if name.hasSuffix(".pdf") { return "doc.richtext" }
        if name.hasSuffix(".md") { return "doc.text" }
        return "doc.plaintext"
    }
}
