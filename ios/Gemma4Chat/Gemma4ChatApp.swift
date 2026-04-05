import SwiftUI

@main
struct Gemma4ChatApp: App {
    @AppStorage("serverHost") private var serverHost = ""
    @AppStorage("serverPort") private var serverPort = "8000"
    @State private var isConfigured = false

    var body: some Scene {
        WindowGroup {
            if isConfigured {
                ChatView(host: serverHost, port: Int(serverPort) ?? 8000)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                isConfigured = false
                            } label: {
                                Image(systemName: "gear")
                            }
                        }
                    }
            } else {
                ServerSetupView(
                    serverHost: $serverHost,
                    serverPort: $serverPort,
                    onConnect: { isConfigured = true }
                )
            }
        }
    }

    init() {
        // Auto-connect if we already have a saved host
        let saved = UserDefaults.standard.string(forKey: "serverHost") ?? ""
        _isConfigured = State(initialValue: !saved.isEmpty)
    }
}
