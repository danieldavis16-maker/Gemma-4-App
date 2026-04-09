import Foundation

class ProjectStore {
    private var storageURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("projects.json")
    }

    func loadAll() -> [Project] {
        guard let data = try? Data(contentsOf: storageURL) else { return [] }
        return (try? JSONDecoder().decode([Project].self, from: data)) ?? []
    }

    func saveAll(_ projects: [Project]) {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: storageURL)
    }
}
