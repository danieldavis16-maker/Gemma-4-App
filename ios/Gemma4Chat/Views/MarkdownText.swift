import SwiftUI

struct MarkdownText: View {
    let text: String
    let foregroundColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parseBlocks(text).enumerated()), id: \.offset) { _, block in
                switch block {
                case .code(let lang, let code):
                    codeBlock(language: lang, code: code)
                case .heading(let level, let content):
                    Text(content)
                        .font(level == 1 ? .headline : level == 2 ? .subheadline : .subheadline)
                        .bold()
                        .foregroundColor(foregroundColor)
                case .bullet(let content):
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundColor(foregroundColor)
                        inlineMarkdown(content)
                    }
                case .numbered(let num, let content):
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(num).")
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .trailing)
                        inlineMarkdown(content)
                    }
                case .paragraph(let content):
                    inlineMarkdown(content)
                }
            }
        }
    }

    // MARK: - Inline markdown (bold, italic, code)

    @ViewBuilder
    private func inlineMarkdown(_ text: String) -> some View {
        Text(buildAttributedString(text))
            .foregroundColor(foregroundColor)
    }

    private func buildAttributedString(_ input: String) -> AttributedString {
        var result = AttributedString()
        var remaining = input[...]

        while !remaining.isEmpty {
            // Inline code: `code`
            if remaining.hasPrefix("`"), let end = remaining.dropFirst().firstIndex(of: "`") {
                let code = remaining[remaining.index(after: remaining.startIndex)..<end]
                var attr = AttributedString(String(code))
                attr.font = .system(.body, design: .monospaced)
                attr.backgroundColor = .gray.opacity(0.2)
                result += attr
                remaining = remaining[remaining.index(after: end)...]
            }
            // Bold: **text**
            else if remaining.hasPrefix("**"), let range = remaining.range(of: "**", range: remaining.index(remaining.startIndex, offsetBy: 2)..<remaining.endIndex) {
                let bold = remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<range.lowerBound]
                var attr = AttributedString(String(bold))
                attr.font = .body.bold()
                result += attr
                remaining = remaining[range.upperBound...]
            }
            // Italic: *text*
            else if remaining.hasPrefix("*"), !remaining.hasPrefix("**"),
                    let end = remaining.dropFirst().firstIndex(of: "*") {
                let italic = remaining[remaining.index(after: remaining.startIndex)..<end]
                var attr = AttributedString(String(italic))
                attr.font = .body.italic()
                result += attr
                remaining = remaining[remaining.index(after: end)...]
            }
            // Regular character
            else {
                let char = remaining[remaining.startIndex]
                result += AttributedString(String(char))
                remaining = remaining[remaining.index(after: remaining.startIndex)...]
            }
        }

        return result
    }

    // MARK: - Code block view

    @ViewBuilder
    private func codeBlock(language: String, code: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !language.isEmpty {
                HStack {
                    Text(language)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = code
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray4))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(foregroundColor)
                    .padding(10)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - Block parser

    private enum Block {
        case code(lang: String, code: String)
        case heading(level: Int, content: String)
        case bullet(content: String)
        case numbered(num: Int, content: String)
        case paragraph(content: String)
    }

    private func parseBlocks(_ text: String) -> [Block] {
        var blocks: [Block] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]

            // Fenced code block
            if line.hasPrefix("```") {
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                blocks.append(.code(lang: lang, code: codeLines.joined(separator: "\n")))
                i += 1
                continue
            }

            // Headings
            if line.hasPrefix("### ") {
                blocks.append(.heading(level: 3, content: String(line.dropFirst(4))))
            } else if line.hasPrefix("## ") {
                blocks.append(.heading(level: 2, content: String(line.dropFirst(3))))
            } else if line.hasPrefix("# ") {
                blocks.append(.heading(level: 1, content: String(line.dropFirst(2))))
            }
            // Bullet lists
            else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                blocks.append(.bullet(content: String(line.dropFirst(2))))
            }
            // Numbered lists
            else if let match = line.range(of: #"^(\d+)\.\s"#, options: .regularExpression) {
                let num = Int(line[line.startIndex..<line.index(before: match.upperBound)].filter(\.isNumber)) ?? 1
                let content = String(line[match.upperBound...])
                blocks.append(.numbered(num: num, content: content))
            }
            // Empty line or paragraph
            else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                // skip
            } else {
                blocks.append(.paragraph(content: line))
            }

            i += 1
        }

        return blocks
    }
}
