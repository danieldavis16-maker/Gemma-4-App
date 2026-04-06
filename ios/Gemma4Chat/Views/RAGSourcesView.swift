import SwiftUI

struct RAGSourcesView: View {
    let sources: [RAGSource]
    @State private var isExpanded = false

    var body: some View {
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.caption2)
                        Text("\(sources.count) source\(sources.count == 1 ? "" : "s") used")
                            .font(.caption2)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.purple)
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(sources) { source in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.text")
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                    Text(source.filename)
                                        .font(.caption2.bold())
                                        .foregroundColor(.primary)
                                }
                                Text(source.excerpt + "...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.purple.opacity(0.06))
                            .cornerRadius(8)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}
