import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

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
                        Button("Copy") {
                            UIPasteboard.general.string = message.content
                        }
                    }

                Text(timeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
