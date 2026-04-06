import SwiftUI

struct HistorySheet: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        NavigationStack {
            List {
                if viewModel.conversations.isEmpty {
                    ContentUnavailableView(
                        "No Conversations",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Start chatting to create your first conversation.")
                    )
                } else {
                    ForEach(viewModel.conversations) { conversation in
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
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteConversation(viewModel.conversations[index])
                        }
                    }
                }
            }
            .navigationTitle("History")
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
