import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    var isLastAssistant: Bool = false
    var isStreaming: Bool = false
    var onRegenerate: (() -> Void)?

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .cornerRadius(16)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }

                        if message.role == .assistant && !message.content.isEmpty {
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
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    }

                HStack(spacing: 8) {
                    Text(timeString)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if isLastAssistant && !isStreaming && !message.content.isEmpty {
                        Button {
                            onRegenerate?()
                        } label: {
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
        case .user:
            return .blue
        case .assistant:
            return Color(.systemGray5)
        case .system:
            return .orange.opacity(0.3)
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
