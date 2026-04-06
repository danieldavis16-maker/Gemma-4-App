import SwiftUI

struct ChatView: View {
    let modelPath: String
    let supportsImages: Bool
    @StateObject private var viewModel = ChatViewModel()
    @State private var showImagePicker = false
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Model loading status
                if !viewModel.isModelLoaded {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading model...")
                            .font(.caption)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.2))
                }

                if let error = viewModel.modelLoadError {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(8)
                }

                // Token speed indicator
                if viewModel.isStreaming && viewModel.tokensPerSecond > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text(String(format: "%.1f tokens/sec", viewModel.tokensPerSecond))
                            .font(.caption2)
                            .monospacedDigit()
                        Text("·")
                            .font(.caption2)
                        Text("\(viewModel.tokenCount) tokens")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                }

                // System prompt indicator
                if !viewModel.settings.systemPrompt.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                        Text(viewModel.settings.systemPrompt.prefix(50))
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.08))
                }

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.messages) { message in
                                let isLast = message.id == viewModel.messages.last?.id
                                    && message.role == .assistant
                                MessageBubble(
                                    message: message,
                                    isLastAssistant: isLast,
                                    isStreaming: viewModel.isStreaming,
                                    onRegenerate: { viewModel.regenerateLastResponse() }
                                )
                                .id(message.id)

                                // Show RAG sources after last assistant message
                                if message.id == viewModel.messages.last?.id
                                    && message.role == .assistant
                                    && !viewModel.isStreaming
                                    && !viewModel.lastRAGSources.isEmpty {
                                    RAGSourcesView(sources: viewModel.lastRAGSources)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: viewModel.messages.last?.content) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                }

                Divider()

                // Pending image preview
                if let img = viewModel.pendingImage {
                    HStack {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            .clipped()
                        Button {
                            viewModel.pendingImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                }

                // Input bar
                HStack(spacing: 8) {
                    SearchToggle(isEnabled: $viewModel.webSearchEnabled)
                    RAGToggle(isEnabled: $viewModel.ragEnabled)

                    if supportsImages {
                        Menu {
                            Button {
                                showCamera = true
                            } label: {
                                Label("Camera", systemImage: "camera")
                            }
                            Button {
                                showImagePicker = true
                            } label: {
                                Label("Photo Library", systemImage: "photo")
                            }
                        } label: {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                        }
                    }

                    TextField("Message Gemma...", text: $viewModel.currentInput, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)

                    if viewModel.isStreaming {
                        Button(action: { viewModel.stopGeneration() }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.red)
                        }
                    } else {
                        Button(action: { viewModel.sendMessage() }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(canSend ? .blue : .gray)
                        }
                        .disabled(!canSend)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Gemma 4 Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.showHistorySheet = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        Button {
                            viewModel.newConversation()
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.showDocumentsSheet = true
                        } label: {
                            Image(systemName: "folder")
                        }
                        Button {
                            viewModel.showSettingsSheet = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showDocumentsSheet) {
                DocumentsSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showSettingsSheet) {
                SettingsSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showHistorySheet) {
                HistorySheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $viewModel.pendingImage)
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(image: $viewModel.pendingImage, sourceType: .camera)
            }
            .task {
                await viewModel.loadModel(path: modelPath)
            }
        }
    }

    private var canSend: Bool {
        let hasText = !viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasImage = viewModel.pendingImage != nil
        return (hasText || hasImage) && !viewModel.isStreaming && viewModel.isModelLoaded
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}
