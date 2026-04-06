import SwiftUI

struct ModelDownloadView: View {
    @ObservedObject var modelManager: ModelManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "cpu")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                        .padding(.top, 32)

                    Text("Choose a Model")
                        .font(.title2.bold())

                    Text("Models run 100% on-device. No server needed.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(availableModels) { model in
                        ModelCard(
                            model: model,
                            isDownloaded: modelManager.downloadedModels.contains(model.id),
                            isSelected: modelManager.selectedModelId == model.id,
                            isDownloading: modelManager.isDownloading,
                            progress: modelManager.downloadProgress,
                            statusText: modelManager.statusText,
                            onDownload: {
                                Task { await modelManager.downloadModel(model) }
                            },
                            onSelect: {
                                modelManager.selectModel(model.id)
                            },
                            onDelete: {
                                modelManager.deleteModel(model)
                            }
                        )
                    }

                    if let error = modelManager.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    Text("Requires Wi-Fi for download.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Gemma 4 Chat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ModelCard: View {
    let model: ModelOption
    let isDownloaded: Bool
    let isSelected: Bool
    let isDownloading: Bool
    let progress: Double
    let statusText: String
    let onDownload: () -> Void
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(model.name)
                            .font(.headline)
                        if model.supportsImages {
                            Label("Vision", systemImage: "eye")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }
                    }
                    Text(model.sizeLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if isDownloaded && isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }

            Text(model.description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if isDownloaded {
                HStack(spacing: 12) {
                    Button(action: onSelect) {
                        Text(isSelected ? "Active" : "Use This Model")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.green : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(isSelected)

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                            .padding(10)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                }
            } else if isDownloading {
                VStack(spacing: 6) {
                    ProgressView(value: progress)
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: onDownload) {
                    Label("Download", systemImage: "arrow.down.circle")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}
