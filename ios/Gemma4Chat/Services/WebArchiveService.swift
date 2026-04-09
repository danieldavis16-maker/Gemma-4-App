import Foundation

class WebArchiveService {

    static func fetchAndIngest(url: String, ragService: OnDeviceRAGService) async throws -> Int {
        guard let requestURL = URL(string: url) else {
            throw NSError(domain: "WebArchive", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: requestURL)
        request.setValue("Mozilla/5.0 (iPhone)", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "WebArchive", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not decode page"])
        }

        // Strip HTML tags to get plain text
        let plainText = html
            .replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !plainText.isEmpty else {
            throw NSError(domain: "WebArchive", code: 3, userInfo: [NSLocalizedDescriptionKey: "No text content found"])
        }

        // Ingest into RAG
        let filename = "web_\(requestURL.host ?? "page")_\(Date().timeIntervalSince1970).txt"
        let textData = plainText.data(using: .utf8)!
        return try ragService.ingestDocument(data: textData, filename: filename)
    }
}
