import SwiftUI

struct ChatView: View {
    let host: String
    let port: Int

    @StateObject private var viewModel: ChatViewModel

    init(host: String = "localhost", port: Int = 8000) {
        self.host = host
        self.port = port
        _viewModel = StateObject(wrappedValue: ChatViewModel(host: host, port: port))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Connection status
                if !viewModel.isConnected {
                    HStack {
                        Image(systemName: "wifi.slash")
                        Text("Disconnected")
                            .font(.caption)
                        Button("Retry") { viewModel.reconnect() }
                            .font(.caption)
                            .buttonStyle(.bordered)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.2))
                }

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Input bar
                HStack(spacing: 8) {
                    SearchToggle(isEnabled: $viewModel.webSearchEnabled)
                    RAGToggle(isEnabled: $viewModel.ragEnabled)

                    TextField("Message Gemma...", text: $viewModel.currentInput, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)

                    Button(action: { viewModel.sendMessage() }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(canSend ? .blue : .gray)
                    }
                    .disabled(!canSend)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Gemma 4 Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showDocumentsSheet = true
                    } label: {
                        Image(systemName: "folder")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showDocumentsSheet) {
                DocumentsSheet(viewModel: viewModel)
            }
        }
    }

    private var canSend: Bool {
        !viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.isStreaming
            && viewModel.isConnected
    }
}
