import SwiftUI

struct ChatView: View {
    @ObservedObject var modelManager: ModelManager
    var onSwitchModel: (() -> Void)?
    @StateObject private var viewModel = ChatViewModel()
    @State private var showImagePicker = false
    @State private var showCamera = false

    private var supportsImages: Bool {
        modelManager.selectedModel?.supportsImages ?? false
    }

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
                    VStack(spacing: 8) {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                        Button("Switch Model") {
                            onSwitchModel?()
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
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

                // Project indicator
                if let project = viewModel.currentProject {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.caption2)
                        Text(project.name)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08))
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
                                    onRegenerate: { viewModel.regenerateLastResponse() },
                                    onSpeak: { viewModel.speakLastResponse() },
                                    onBookmark: { viewModel.toggleBookmark(messageId: message.id) },
                                    onShareScreenshot: { viewModel.shareMessageAsScreenshot(message) }
                                )
                                .id(message.id)

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

                // Voice recording indicator
                if viewModel.voiceService.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("Listening...")
                            .font(.caption)
                        if !viewModel.voiceService.transcribedText.isEmpty {
                            Text(viewModel.voiceService.transcribedText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.08))
                }

                // Speaking indicator
                if viewModel.voiceService.isSpeaking {
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text("Speaking...")
                            .font(.caption2)
                        Spacer()
                        Button("Stop") {
                            viewModel.voiceService.stopSpeaking()
                        }
                        .font(.caption2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.08))
                }

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
                    } else if canSend {
                        Button(action: { viewModel.sendMessage() }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.blue)
                        }
                    } else {
                        Button(action: {
                            if viewModel.voiceService.isRecording {
                                viewModel.voiceService.stopRecording()
                                viewModel.currentInput = viewModel.voiceService.transcribedText
                            } else {
                                viewModel.voiceService.requestPermission()
                                viewModel.voiceService.startRecording()
                            }
                        }) {
                            Image(systemName: viewModel.voiceService.isRecording ? "mic.fill" : "mic")
                                .font(.system(size: 24))
                                .foregroundColor(viewModel.voiceService.isRecording ? .red : .blue)
                                .frame(width: 32, height: 32)
                        }
                        .disabled(!viewModel.isModelLoaded)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .navigationTitle(viewModel.currentProject?.name ?? "Gemma 4 Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 10) {
                        // Model selector
                        modelSelector

                        Button {
                            viewModel.showProjectsSheet = true
                        } label: {
                            Image(systemName: "folder.badge.gearshape")
                        }
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
                    HStack(spacing: 10) {
                        Menu {
                            Button {
                                viewModel.exportCurrentConversation(format: .text)
                            } label: {
                                Label("Export as Text", systemImage: "doc.text")
                            }
                            Button {
                                viewModel.exportCurrentConversation(format: .pdf)
                            } label: {
                                Label("Export as PDF", systemImage: "doc.richtext")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(viewModel.currentConversationId == nil)

                        Button {
                            viewModel.showSearchSheet = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        Button {
                            viewModel.showBookmarksSheet = true
                        } label: {
                            Image(systemName: "bookmark")
                        }
                        Menu {
                            Button {
                                viewModel.showTemplatesSheet = true
                            } label: {
                                Label("Templates", systemImage: "rectangle.grid.2x2")
                            }
                            Button {
                                viewModel.showDocumentsSheet = true
                            } label: {
                                Label("Documents", systemImage: "doc.text")
                            }
                            Button {
                                viewModel.showSettingsSheet = true
                            } label: {
                                Label("Settings", systemImage: "gearshape")
                            }
                            Divider()
                            Button {
                                viewModel.togglePin()
                            } label: {
                                let isPinned = viewModel.conversations.first(where: { $0.id == viewModel.currentConversationId })?.isPinned ?? false
                                Label(isPinned ? "Unpin" : "Pin Chat", systemImage: isPinned ? "pin.slash" : "pin")
                            }
                            .disabled(viewModel.currentConversationId == nil)
                            Button {
                                viewModel.shareConversationAsScreenshot()
                            } label: {
                                Label("Share as Image", systemImage: "camera")
                            }
                            .disabled(viewModel.currentConversationId == nil)
                        } label: {
                            Image(systemName: "ellipsis.circle")
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
            .sheet(isPresented: $viewModel.showProjectsSheet) {
                ProjectsView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showTemplatesSheet) {
                TemplatesView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showSearchSheet) {
                SearchView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showBookmarksSheet) {
                BookmarksView(viewModel: viewModel)
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $viewModel.pendingImage)
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(image: $viewModel.pendingImage, sourceType: .camera)
            }
            .task {
                await viewModel.loadModel(path: modelManager.modelPath.path)
                viewModel.checkSiriQuestion()
            }
            .onAppear {
                viewModel.voiceService.requestPermission()
            }
        }
    }

    // MARK: - Model Selector

    @ViewBuilder
    private var modelSelector: some View {
        Menu {
            ForEach(availableModels) { model in
                let isSelected = modelManager.selectedModelId == model.id
                let isDownloaded = modelManager.downloadedModels.contains(model.id)

                Button {
                    if isDownloaded && !isSelected {
                        modelManager.selectModel(model.id)
                        // Reload with new model
                        viewModel.isModelLoaded = false
                        viewModel.modelLoadError = nil
                        Task {
                            await viewModel.loadModel(path: modelManager.modelPath.path)
                        }
                    } else if !isDownloaded {
                        onSwitchModel?()
                    }
                } label: {
                    HStack {
                        Text(model.name)
                        if model.supportsImages {
                            Text("(Vision)")
                        }
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark")
                        } else if !isDownloaded {
                            Image(systemName: "arrow.down.circle")
                        }
                    }
                }
                .disabled(isSelected)
            }

            Divider()

            Button {
                onSwitchModel?()
            } label: {
                Label("Manage Models", systemImage: "arrow.down.app")
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "cpu")
                    .font(.system(size: 14))
                Text(modelManager.selectedModel?.name ?? "Model")
                    .font(.caption2)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .cornerRadius(8)
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
