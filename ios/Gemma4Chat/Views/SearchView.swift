import SwiftUI

struct SearchView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var searchText = ""

    private var searchResults: [(conversation: Conversation, message: ChatMessage)] {
        guard searchText.count >= 2 else { return [] }
        let query = searchText.lowercased()
        var results: [(Conversation, ChatMessage)] = []
        for conv in viewModel.conversations {
            for msg in conv.messages where msg.content.lowercased().contains(query) {
                results.append((conv, msg))
                if results.count >= 50 { return results }
            }
        }
        return results
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.count < 2 {
                    ContentUnavailableView(
                        "Search Conversations",
                        systemImage: "magnifyingglass",
                        description: Text("Type at least 2 characters to search across all your chats.")
                    )
                } else if searchResults.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("No messages found matching \"\(searchText)\".")
                    )
                } else {
                    ForEach(searchResults, id: \.message.id) { result in
                        Button {
                            viewModel.loadConversation(result.conversation)
                            viewModel.showSearchSheet = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: result.message.role == .user ? "person" : "cpu")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(result.conversation.title)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Text(highlightedText(result.message.content, query: searchText))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search messages...")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        viewModel.showSearchSheet = false
                    }
                }
            }
        }
    }

    private func highlightedText(_ text: String, query: String) -> AttributedString {
        var attributed = AttributedString(String(text.prefix(200)))
        if let range = attributed.range(of: query, options: .caseInsensitive) {
            attributed[range].backgroundColor = .yellow.opacity(0.3)
            attributed[range].font = .subheadline.bold()
        }
        return attributed
    }
}
