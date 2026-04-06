import SwiftUI

@main
struct Gemma4ChatApp: App {
    @StateObject private var modelManager = ModelManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if modelManager.isDownloaded {
                    ChatView(modelPath: modelManager.modelPath.path)
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
