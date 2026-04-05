import Foundation

class WebSearchService {
    func search(query: String) async -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://html.duckduckgo.com/html/?q=\(encoded)") else {
            return ""
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return "" }
            return parseResults(html: html)
        } catch {
            return ""
        }
    }

    private func parseResults(html: String) -> String {
        var results: [String] = []

        // Extract snippets from DuckDuckGo HTML results
        let pattern = "class=\"result__snippet\"[^>]*>(.*?)</a>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return ""
        }

        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        for match in matches.prefix(5) {
            if let range = Range(match.range(at: 1), in: html) {
                let snippet = String(html[range])
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#x27;", with: "'")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !snippet.isEmpty {
                    results.append(snippet)
                }
            }
        }

        if results.isEmpty { return "" }

        var context = "Web search results:\n\n"
        for (i, result) in results.enumerated() {
            context += "\(i + 1). \(result)\n\n"
        }
        context += "Use these search results to inform your response."
        return context
    }
}
