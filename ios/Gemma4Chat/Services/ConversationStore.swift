import Foundation

class ConversationStore {
    private var storageURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("conversations.json")
    }

    func loadAll() -> [Conversation] {
        guard let data = try? Data(contentsOf: storageURL) else { return [] }
        return (try? JSONDecoder().decode([Conversation].self, from: data)) ?? []
    }

    func saveAll(_ conversations: [Conversation]) {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: storageURL)
    }

    func loadSettings() -> LLMSettings {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("llm_settings.json")
        guard let data = try? Data(contentsOf: url) else { return .default }
        return (try? JSONDecoder().decode(LLMSettings.self, from: data)) ?? .default
    }

    func saveSettings(_ settings: LLMSettings) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("llm_settings.json")
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: url)
    }
}
