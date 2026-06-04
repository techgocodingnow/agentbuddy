import Foundation

/// MVP compact-style summary for pet status text. This is deliberately
/// deterministic; an agent-backed summarizer can replace this boundary later.
public enum TaskSummary {
    private static let maxWords = 9
    private static let maxCharacters = 72

    public static func compact(from text: String?) -> String? {
        guard var line = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !line.isEmpty else { return nil }

        line = line
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")

        while line.contains("  ") {
            line = line.replacingOccurrences(of: "  ", with: " ")
        }

        line = stripCommonPromptPrefix(from: line)
        line = trimTrailingPunctuation(from: line)

        let words = line.split(separator: " ")
        if words.count > maxWords {
            line = words.prefix(maxWords).joined(separator: " ")
        }
        if line.count > maxCharacters {
            let end = line.index(line.startIndex, offsetBy: maxCharacters)
            line = String(line[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return line.isEmpty ? nil : line
    }

    private static func stripCommonPromptPrefix(from text: String) -> String {
        let prefixes = [
            "please ",
            "can you ",
            "could you ",
            "can we ",
            "ok let do ",
            "ok let's do ",
            "let's do ",
            "lets do ",
            "let do ",
            "let's ",
            "lets ",
        ]
        let lower = text.lowercased()
        for prefix in prefixes where lower.hasPrefix(prefix) {
            return String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private static func trimTrailingPunctuation(from text: String) -> String {
        text.trimmingCharacters(in: CharacterSet(charactersIn: ".!?;:, "))
    }
}
