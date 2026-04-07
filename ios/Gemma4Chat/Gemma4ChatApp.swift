import SwiftUI

@main
struct Gemma4ChatApp: App {
    @StateObject private var modelManager = ModelManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if modelManager.isDownloaded {
                    ChatView(
                        modelPath: modelManager.modelPath.path,
                        supportsImages: modelManager.selectedModel?.supportsImages ?? false,
                        onSwitchModel: {
                            modelManager.isDownloaded = false
                        }
                    )
                } else {
                    ModelDownloadView(modelManager: modelManager)
                }
            }
            .onAppear {
                modelManager.checkModel()
            }
        }
    }
}
