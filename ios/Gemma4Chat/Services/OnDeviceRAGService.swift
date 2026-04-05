import Foundation
import PDFKit

class OnDeviceRAGService {
    struct DocumentChunk: Codable {
        let filename: String
        let content: String
        let chunkIndex: Int
    }

    private var chunks: [DocumentChunk] = []

    private var storageURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("rag_chunks.json")
    }

    init() {
        loadChunks()
    }

    func ingestDocument(data: Data, filename: String) throws -> Int {
        deleteDocument(filename: filename)

        let text: String
        if filename.lowercased().hasSuffix(".pdf") {
            guard let pdf = PDFDocument(data: data) else {
                throw NSError(domain: "RAG", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read PDF"])
            }
            var pages: [String] = []
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i), let pageText = page.string {
                    pages.append(pageText)
                }
            }
            text = pages.joined(separator: "\n")
        } else {
            guard let str = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "RAG", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not read text file"])
            }
            text = str
        }

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "RAG", code: 3, userInfo: [NSLocalizedDescriptionKey: "Document is empty"])
        }

        let newChunks = chunkText(text, chunkSize: 1500, overlap: 200)
            .enumerated()
            .map { DocumentChunk(filename: filename, content: $0.element, chunkIndex: $0.offset) }

        chunks.append(contentsOf: newChunks)
        saveChunks()
        return newChunks.count
    }

    func search(query: String, topK: Int = 5) -> [DocumentChunk] {
        guard !chunks.isEmpty else { return [] }

        let queryWords = Set(tokenize(query))
        guard !queryWords.isEmpty else { return [] }

        let scored: [(chunk: DocumentChunk, score: Double)] = chunks.map { chunk in
            let chunkWords = Set(tokenize(chunk.content))
            let overlap = queryWords.intersection(chunkWords)
            let score = Double(overlap.count) / Double(queryWords.count)
            return (chunk, score)
        }

        return scored
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map(\.chunk)
    }

    func formatContext(chunks: [DocumentChunk]) -> String {
        if chunks.isEmpty { return "" }
        var lines = ["Relevant document excerpts:\n"]
        for chunk in chunks {
            lines.append("[\(chunk.filename)]")
            lines.append(chunk.content + "\n")
        }
        lines.append("Use these excerpts to inform your response. Cite sources when relevant.")
        return lines.joined(separator: "\n")
    }

    func listDocuments() -> [(filename: String, chunkCount: Int)] {
        var counts: [String: Int] = [:]
        for chunk in chunks {
            counts[chunk.filename, default: 0] += 1
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.filename < $1.filename }
    }

    func deleteDocument(filename: String) {
        chunks.removeAll { $0.filename == filename }
        saveChunks()
    }

    // MARK: - Private

    private func chunkText(_ text: String, chunkSize: Int, overlap: Int) -> [String] {
        guard text.count > chunkSize else {
            return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [text]
        }
        var result: [String] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text.index(start, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex
            let chunk = String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                result.append(chunk)
            }
            guard let next = text.index(start, offsetBy: chunkSize - overlap, limitedBy: text.endIndex) else { break }
            start = next
        }
        return result
    }

    private func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 }
    }

    private func loadChunks() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        chunks = (try? JSONDecoder().decode([DocumentChunk].self, from: data)) ?? []
    }

    private func saveChunks() {
        guard let data = try? JSONEncoder().encode(chunks) else { return }
        try? data.write(to: storageURL)
    }
}
