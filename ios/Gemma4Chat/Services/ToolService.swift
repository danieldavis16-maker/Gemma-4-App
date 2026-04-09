import Foundation

class ToolService {

    /// Check if assistant response contains a tool call and execute it
    static func processToolCalls(in text: String) -> (cleanText: String, toolResults: [ToolCall])? {
        // Look for patterns like: [TOOL: calculate("2+2")] or [TOOL: date()]
        let pattern = #"\[TOOL:\s*(\w+)\("?([^")\]]*)"?\)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return nil }

        var cleanText = text
        var results: [ToolCall] = []

        for match in matches.reversed() {
            guard let fullRange = Range(match.range, in: text),
                  let nameRange = Range(match.range(at: 1), in: text),
                  let argsRange = Range(match.range(at: 2), in: text) else { continue }

            let toolName = String(text[nameRange])
            let toolArgs = String(text[argsRange])

            if let tool = availableTools.first(where: { $0.name == toolName }) {
                let result = tool.execute(toolArgs)
                var call = ToolCall(name: toolName, arguments: toolArgs)
                call.result = result
                results.append(call)

                cleanText.replaceSubrange(fullRange, with: "**\(toolName)**: \(result)")
            }
        }

        return results.isEmpty ? nil : (cleanText, results)
    }

    /// Generate the tool instruction text for the system prompt
    static var toolInstructions: String {
        var instructions = "You have access to the following tools. To use a tool, write [TOOL: name(\"argument\")] in your response.\n\n"
        instructions += "Available tools:\n"
        for tool in availableTools {
            instructions += "- \(tool.name): \(tool.description)\n"
        }
        instructions += "\nExample: To calculate 2+2, write [TOOL: calculate(\"2+2\")]\n"
        instructions += "Example: To get the date, write [TOOL: date(\"\")]\n"
        return instructions
    }
}
