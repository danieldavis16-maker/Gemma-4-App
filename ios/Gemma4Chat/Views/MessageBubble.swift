import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    var isLastAssistant: Bool = false
    var isStreaming: Bool = false
    var onRegenerate: (() -> Void)?
    var onSpeak: (() -> Void)?
    var onBookmark: (() -> Void)?
    var onShareScreenshot: (() -> Void)?

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Group {
                    if message.role == .assistant && !message.content.isEmpty {
                        MarkdownText(text: message.content, foregroundColor: textColor)
                    } else if message.role == .tool {
                        HStack(spacing: 4) {
                            Image(systemName: "wrench.and.screwdriver")
                                .font(.caption)
                            Text(message.content)
                        }
                        .font(.caption)
                    } else {
                        Text(message.content)
                    }
                }
                .padding(12)
                .background(backgroundColor)
                .foregroundColor(textColor)
                .cornerRadius(16)
                .overlay(alignment: .topTrailing) {
                    if message.isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(6)
                    }
                }
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.content
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }

                    Button {
                        onBookmark?()
                    } label: {
                        Label(message.isBookmarked ? "Remove Bookmark" : "Bookmark", systemImage: message.isBookmarked ? "bookmark.slash" : "bookmark")
                    }

                    Button {
                        onShareScreenshot?()
                    } label: {
                        Label("Share as Image", systemImage: "camera")
                    }

                    if !message.content.isEmpty {
                        Button {
                            let activityVC = UIActivityViewController(
                                activityItems: [message.content],
                                applicationActivities: nil
                            )
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first {
                                window.rootViewController?.present(activityVC, animated: true)
                            }
                        } label: {
                            Label("Share Text", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text(timeString)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if isLastAssistant && !isStreaming && !message.content.isEmpty {
                        Button { onSpeak?() } label: {
                            Image(systemName: "speaker.wave.2")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Button { onRegenerate?() } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser { Spacer() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return Color(.systemGray5)
        case .system: return .orange.opacity(0.3)
        case .tool: return .green.opacity(0.2)
        }
    }

    private var textColor: Color {
        message.isUser ? .white : .primary
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
}
