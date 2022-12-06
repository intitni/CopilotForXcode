import CopilotModel
import Foundation

let suggestionStart = "/*========== Copilot Suggestion"
let suggestionEnd = "*///======== End of Copilot Suggestion"

// NOTE: Every lines from Xcode Extension has a line break at its end, even the last line.
// NOTE: Copilot's completion always start at character 0, no matter where the cursor is.
// NOTE: range.end and postion in Copilot's completion are useless, don't bother looking at them.

public struct SuggestionInjector {
    public init() {}

    public func rejectCurrentSuggestions(
        from content: inout [String],
        cursorPosition: inout CursorPosition
    ) {
        var ranges = [Range<Int>]()
        var suggestionStartIndex = -1

        for (index, line) in content.enumerated() {
            if line.hasPrefix(suggestionStart) {
                suggestionStartIndex = index
            }
            if suggestionStartIndex >= 0, line.hasPrefix(suggestionEnd) {
                ranges.append(.init(uncheckedBounds: (suggestionStartIndex, index)))
                suggestionStartIndex = -1
            }
        }

        for range in ranges.lazy.reversed() {
            for i in stride(from: range.endIndex, through: range.startIndex, by: -1) {
                if i <= cursorPosition.line, cursorPosition.line >= 0 {
                    cursorPosition = .init(
                        line: cursorPosition.line - 1,
                        character: i == cursorPosition.line ? 0 : cursorPosition.character
                    )
                }
                content.remove(at: i)
            }
        }
    }

    public func proposeSuggestion(
        intoContentWithoutSuggestion content: inout [String],
        completion: CopilotCompletion,
        index: Int,
        count: Int
    ) {
        let start = completion.range.start
        let startText = "\(suggestionStart) \(index + 1)/\(count)"
        var lines = [startText + "\n"]
        lines.append(contentsOf: completion.text.breakLines(appendLineBreakToLastLine: true))
        lines.append(suggestionEnd + "\n")
        if lines.count <= 2 { return }

        let existedLine = start.line < content.endIndex ? content[start.line] : nil
        let commonPrefix = longestCommonPrefix(of: lines[1], and: existedLine ?? "")

        if !commonPrefix.isEmpty {
            lines[1].replaceSubrange(
                lines[1].startIndex ..< (
                    lines[1].index(
                        lines[1].startIndex,
                        offsetBy: commonPrefix.count,
                        limitedBy: lines[1].endIndex
                    ) ?? lines[1].endIndex
                ),
                with: String(repeating: " ", count: commonPrefix.count - 1) + "^"
            )
        }

        let lineIndex = start.line + {
            guard let existedLine else { return 0 }
            if existedLine.isEmptyOrNewLine { return 1 }
            if !commonPrefix.isEmpty, commonPrefix.count <= existedLine.count - 1 { return 1 }
            return 0
        }()
        if content.endIndex < lineIndex {
            content.append(contentsOf: lines)
        } else {
            content.insert(contentsOf: lines, at: lineIndex)
        }
    }

    public func acceptSuggestion(
        intoContentWithoutSuggestion content: inout [String],
        cursorPosition: inout CursorPosition,
        completion: CopilotCompletion
    ) {
        let start = completion.range.start
        let suggestionContent = completion.text

        let existedLine = start.line < content.endIndex ? content[start.line] : nil
        let commonPrefix = longestCommonPrefix(of: suggestionContent, and: existedLine ?? "")

        if let existedLine, existedLine.count > 1, !commonPrefix.isEmpty {
            content.remove(at: start.line)
        } else if content.count > start.line,
                  content[start.line].isEmpty || content[start.line] == "\n"
        {
            content.remove(at: start.line)
        }

        let toBeInserted = suggestionContent.breakLines(appendLineBreakToLastLine: true)
        if content.endIndex < start.line {
            content.append(contentsOf: toBeInserted)
            cursorPosition = .init(
                line: toBeInserted.endIndex,
                character: (toBeInserted.last?.count ?? 1) - 1
            )
        } else {
            content.insert(
                contentsOf: toBeInserted,
                at: start.line
            )
            cursorPosition = .init(
                line: start.line + toBeInserted.count - 1,
                character: (toBeInserted.last?.count ?? 1) - 1
            )
        }
    }
}

extension String {
    func breakLines(appendLineBreakToLastLine: Bool = false) -> [String] {
        let lines = split(separator: "\n", omittingEmptySubsequences: false)
        var all = [String]()
        for (index, line) in lines.enumerated() {
            if !appendLineBreakToLastLine, index == lines.endIndex - 1 {
                all.append(String(line))
            } else {
                all.append(String(line) + "\n")
            }
        }
        return all
    }

    var isEmptyOrNewLine: Bool {
        isEmpty || self == "\n"
    }
}

func longestCommonPrefix(of a: String, and b: String) -> String {
    let length = min(a.count, b.count)

    var prefix = ""
    for i in 0 ..< length {
        let charIndex = a.index(a.startIndex, offsetBy: i)
        let firstStrChar = a[charIndex]
        guard b[charIndex] == firstStrChar else { return prefix }
        prefix += String(firstStrChar)
    }

    return prefix
}
