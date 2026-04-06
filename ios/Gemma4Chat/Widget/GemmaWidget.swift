import WidgetKit
import SwiftUI

struct GemmaWidgetEntry: TimelineEntry {
    let date: Date
    let lastMessage: String
    let conversationCount: Int
}

struct GemmaWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GemmaWidgetEntry {
        GemmaWidgetEntry(date: Date(), lastMessage: "Ask Gemma anything...", conversationCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (GemmaWidgetEntry) -> Void) {
        let entry = GemmaWidgetEntry(
            date: Date(),
            lastMessage: loadLastMessage(),
            conversationCount: loadConversationCount()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GemmaWidgetEntry>) -> Void) {
        let entry = GemmaWidgetEntry(
            date: Date(),
            lastMessage: loadLastMessage(),
            conversationCount: loadConversationCount()
        )
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
        completion(timeline)
    }

    private func loadLastMessage() -> String {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("conversations.json")
        guard let data = try? Data(contentsOf: url),
              let conversations = try? JSONDecoder().decode([WidgetConversation].self, from: data),
              let last = conversations.first,
              let lastMsg = last.messages.last(where: { $0.role == "assistant" }) else {
            return "Ask Gemma anything..."
        }
        return String(lastMsg.content.prefix(100))
    }

    private func loadConversationCount() -> Int {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("conversations.json")
        guard let data = try? Data(contentsOf: url),
              let conversations = try? JSONDecoder().decode([WidgetConversation].self, from: data) else {
            return 0
        }
        return conversations.count
    }
}

// Minimal decodable types for the widget
private struct WidgetConversation: Codable {
    let messages: [WidgetMessage]
}

private struct WidgetMessage: Codable {
    let role: String
    let content: String
}

struct GemmaWidgetSmallView: View {
    let entry: GemmaWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bubble.left.fill")
                    .foregroundColor(.blue)
                Text("Gemma")
                    .font(.headline)
                    .bold()
            }

            Text(entry.lastMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)

            Spacer()

            HStack {
                Image(systemName: "message")
                    .font(.caption2)
                Text("\(entry.conversationCount) chats")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct GemmaWidgetMediumView: View {
    let entry: GemmaWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "bubble.left.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    Text("Gemma 4 Chat")
                        .font(.headline)
                        .bold()
                }

                Text(entry.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                Spacer()

                HStack {
                    Image(systemName: "message")
                        .font(.caption)
                    Text("\(entry.conversationCount) conversations")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "cpu")
                    .font(.system(size: 32))
                    .foregroundColor(.blue.opacity(0.6))
                Text("On-device AI")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80)
        }
        .padding()
    }
}

struct GemmaWidget: Widget {
    let kind = "GemmaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GemmaWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                GemmaWidgetContainerView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                GemmaWidgetContainerView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Gemma Chat")
        .description("Quick access to your on-device AI assistant.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct GemmaWidgetContainerView: View {
    @Environment(\.widgetFamily) var family
    let entry: GemmaWidgetEntry

    var body: some View {
        switch family {
        case .systemMedium:
            GemmaWidgetMediumView(entry: entry)
        default:
            GemmaWidgetSmallView(entry: entry)
        }
    }
}
