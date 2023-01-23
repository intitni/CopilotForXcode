import CopilotModel
import Foundation

let suggestionStart = "/*========== Copilot Suggestion"
let suggestionEnd = "*///======== End of Copilot Suggestion"

// NOTE: Every lines from Xcode Extension has a line break at its end, even the last line.
// NOTE: Copilot's completion always start at character 0, no matter where the cursor is.
// NOTE: range.end and postion in Copilot's completion are useless, don't bother looking at them.

public struct SuggestionInjector {
    public init() {}

    public struct ExtraInfo {
        public var didChangeContent = false
        public var didChangeCursorPosition = false
        public var suggestionRange: ClosedRange<Int>?
        public var modifications: [Modification] = []
        public init() {}
    }

    public func rejectCurrentSuggestions(
        from content: inout [String],
        cursorPosition: inout CursorPosition,
        extraInfo: inout ExtraInfo
    ) {
        var ranges = [ClosedRange<Int>]()
        var suggestionStartIndex = -1

        // find ranges of suggestion comments
        for (index, line) in content.enumerated() {
            if line.hasPrefix(suggestionStart) {
                suggestionStartIndex = index
            }
            if suggestionStartIndex >= 0, line.hasPrefix(suggestionEnd) {
                ranges.append(.init(uncheckedBounds: (suggestionStartIndex, index)))
                suggestionStartIndex = -1
            }
        }

        let reversedRanges = ranges.reversed()

        extraInfo.modifications.append(contentsOf: reversedRanges.map(Modification.deleted))
        extraInfo.didChangeContent = !ranges.isEmpty

        // remove the lines from bottom to top
        for range in reversedRanges {
            for i in stride(from: range.upperBound, through: range.lowerBound, by: -1) {
                if i <= cursorPosition.line, cursorPosition.line >= 0 {
                    cursorPosition = .init(
                        line: cursorPosition.line - 1,
                        character: i == cursorPosition.line ? 0 : cursorPosition.character
                    )
                    extraInfo.didChangeCursorPosition = true
                }
                content.remove(at: i)
            }
        }

        extraInfo.suggestionRange = nil
    }

    public func proposeSuggestion(
        intoContentWithoutSuggestion content: inout [String],
        completion: CopilotCompletion,
        index: Int,
        count: Int,
        extraInfo: inout ExtraInfo
    ) {
        // assemble suggestion comment
        let start = completion.range.start
        let startText = "\(suggestionStart) \(index + 1)/\(count)"
        var lines = [startText + "\n"]
        lines.append(contentsOf: completion.text.breakLines(appendLineBreakToLastLine: true))
        lines.append(suggestionEnd + "\n")

        // if suggestion is empty, returns without modifying the code
        guard lines.count > 2 else { return }

        // replace the common prefix of the first line with space and carrot
        let existedLine = start.line < content.endIndex ? content[start.line] : nil
        let commonPrefix = longestCommonPrefix(of: lines[1], and: existedLine ?? "")

        if !commonPrefix.isEmpty {
            lines[1].replaceSubrange(
                lines[1].startIndex..<(
                    lines[1].index(
                        lines[1].startIndex,
                        offsetBy: commonPrefix.count,
                        limitedBy: lines[1].endIndex
                    ) ?? lines[1].endIndex
                ),
                with: String(repeating: " ", count: commonPrefix.count - 1) + "^"
            )
        }
        
        // if the suggestion is only appeding new lines and spaces, return without modification
        if completion.text.dropFirst(commonPrefix.count).allSatisfy({ $0.isWhitespace || $0.isNewline }) { return }

        let lineIndex = start.line + {
            guard let existedLine else { return 0 }
            if existedLine.isEmptyOrNewLine { return 1 }
            if !commonPrefix.isEmpty, commonPrefix.count <= existedLine.count - 1 { return 1 }
            return 0
        }()
        if content.endIndex < lineIndex {
            extraInfo.didChangeContent = true
            extraInfo.suggestionRange = content.endIndex...content.endIndex + lines.count - 1
            extraInfo.modifications.append(.inserted(content.endIndex, lines))
            content.append(contentsOf: lines)
        } else {
            extraInfo.didChangeContent = true
            extraInfo.suggestionRange = lineIndex...lineIndex + lines.count - 1
            extraInfo.modifications.append(.inserted(lineIndex, lines))
            content.insert(contentsOf: lines, at: lineIndex)
        }
    }

    public func acceptSuggestion(
        intoContentWithoutSuggestion content: inout [String],
        cursorPosition: inout CursorPosition,
        completion: CopilotCompletion,
        extraInfo: inout ExtraInfo
    ) {
        extraInfo.didChangeContent = true
        extraInfo.didChangeCursorPosition = true
        extraInfo.suggestionRange = nil
        let start = completion.range.start
        let suggestionContent = completion.text

        let existedLine = start.line < content.endIndex ? content[start.line] : nil
        let commonPrefix = longestCommonPrefix(of: suggestionContent, and: existedLine ?? "")

        if let existedLine, existedLine.count > 1, !commonPrefix.isEmpty {
            extraInfo.modifications.append(.deleted(start.line...start.line))
            content.remove(at: start.line)
        } else if content.count > start.line,
                  content[start.line].isEmpty || content[start.line] == "\n"
        {
            extraInfo.modifications.append(.deleted(start.line...start.line))
            content.remove(at: start.line)
        }

        let toBeInserted = suggestionContent.breakLines(appendLineBreakToLastLine: true)
        if content.endIndex < start.line {
            extraInfo.modifications.append(.inserted(content.endIndex, toBeInserted))
            content.append(contentsOf: toBeInserted)
            cursorPosition = .init(
                line: toBeInserted.endIndex,
                character: (toBeInserted.last?.count ?? 1) - 1
            )
        } else {
            extraInfo.modifications.append(.inserted(start.line, toBeInserted))
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
    for i in 0..<length {
        let charIndex = a.index(a.startIndex, offsetBy: i)
        let firstStrChar = a[charIndex]
        guard b[charIndex] == firstStrChar else { return prefix }
        prefix += String(firstStrChar)
    }

    return prefix
}
