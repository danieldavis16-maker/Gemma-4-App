import AppIntents
import Foundation

struct AskGemmaIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Gemma"
    static var description: IntentDescription = "Ask Gemma a question using the on-device AI model"
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Question")
    var question: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // Store the question so the app can pick it up
        UserDefaults.standard.set(question, forKey: "siriQuestion")

        return .result(dialog: "Opening Gemma to answer: \(question)")
    }
}

struct GemmaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskGemmaIntent(),
            phrases: [
                "Ask \(.applicationName) \(\.$question)",
                "Ask \(.applicationName)",
                "Chat with \(.applicationName)",
            ],
            shortTitle: "Ask Gemma",
            systemImageName: "bubble.left.fill"
        )
    }
}
