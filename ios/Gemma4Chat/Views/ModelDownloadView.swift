import SwiftUI

struct ModelDownloadView: View {
    @ObservedObject var modelManager: ModelManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "arrow.down.app")
                    .font(.system(size: 56))
                    .foregroundColor(.blue)

                Text("Download Gemma Model")
                    .font(.title2.bold())

                Text("A ~800 MB language model will be downloaded to run AI 100% locally on your device. No server needed.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if modelManager.isDownloading {
                    VStack(spacing: 12) {
                        ProgressView(value: modelManager.downloadProgress)
                            .padding(.horizontal, 40)
                        Text(modelManager.statusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = modelManager.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button(action: {
                    Task { await modelManager.downloadModel() }
                }) {
                    Text(modelManager.error != nil ? "Retry Download" : "Download Model")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(modelManager.isDownloading ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(modelManager.isDownloading)
                .padding(.horizontal, 32)

                Text("Requires Wi-Fi. Model is stored on-device.")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()
                Spacer()
            }
            .navigationTitle("Gemma 4 Chat")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
