import SwiftUI

struct BookmarksView: View {
    @ObservedObject var viewModel: ChatViewModel

    private var bookmarkedMessages: [(conversation: Conversation, message: ChatMessage)] {
        var results: [(Conversation, ChatMessage)] = []
        for conv in viewModel.conversations {
            for msg in conv.messages where msg.isBookmarked {
                results.append((conv, msg))
            }
        }
        return results.sorted { $0.message.timestamp > $1.message.timestamp }
    }

    var body: some View {
        NavigationStack {
            List {
                if bookmarkedMessages.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Long-press a message and tap Bookmark to save it here.")
                    )
                } else {
                    ForEach(bookmarkedMessages, id: \.message.id) { result in
                        Button {
                            viewModel.loadConversation(result.conversation)
                            viewModel.showBookmarksSheet = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text(result.conversation.title)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(result.message.timestamp, style: .relative)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(result.message.content)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(4)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        viewModel.showBookmarksSheet = false
                    }
                }
            }
        }
    }
}
