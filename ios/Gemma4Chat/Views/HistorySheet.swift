import SwiftUI

struct HistorySheet: View {
    @ObservedObject var viewModel: ChatViewModel

    private var filteredConversations: [Conversation] {
        let base: [Conversation]
        if let project = viewModel.currentProject {
            base = viewModel.conversations.filter { project.conversationIds.contains($0.id) }
        } else {
            base = viewModel.conversations
        }
        // Pinned first, then by date
        return base.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.updatedAt > b.updatedAt
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredConversations.isEmpty {
                    ContentUnavailableView(
                        "No Conversations",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Start chatting to create your first conversation.")
                    )
                } else {
                    ForEach(filteredConversations) { conversation in
                        Button {
                            viewModel.loadConversation(conversation)
                            viewModel.showHistorySheet = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    if conversation.isPinned {
                                        Image(systemName: "pin.fill")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                    Text(conversation.title)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                                HStack {
                                    Text("\(conversation.messages.count) messages")
                                    Text("·")
                                    Text(conversation.updatedAt, style: .relative)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                if !conversation.tags.isEmpty {
                                    HStack(spacing: 4) {
                                        ForEach(conversation.tags, id: \.self) { tag in
                                            Text(tag)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteConversation(conversation)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Menu {
                                Button {
                                    viewModel.exportConversation(conversation, format: .text)
                                } label: {
                                    Label("Text", systemImage: "doc.text")
                                }
                                Button {
                                    viewModel.exportConversation(conversation, format: .pdf)
                                } label: {
                                    Label("PDF", systemImage: "doc.richtext")
                                }
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
            .navigationTitle(viewModel.currentProject != nil ? "\(viewModel.currentProject!.name) History" : "History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        viewModel.showHistorySheet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.newConversation()
                        viewModel.showHistorySheet = false
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
}
