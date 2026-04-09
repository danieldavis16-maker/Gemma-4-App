import SwiftUI

struct HistorySheet: View {
    @ObservedObject var viewModel: ChatViewModel

    private var filteredConversations: [Conversation] {
        if let project = viewModel.currentProject {
            return viewModel.conversations.filter { project.conversationIds.contains($0.id) }
        }
        return viewModel.conversations
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
                                Text(conversation.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                HStack {
                                    Text("\(conversation.messages.count) messages")
                                    Text("·")
                                    Text(conversation.updatedAt, style: .relative)
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
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
