import Foundation
import SuggestionBasic

// NOTE: Every lines from Xcode Extension has a line break at its end, even the last line.
// NOTE: Copilot's completion always start at character 0, no matter where the cursor is.

public struct SuggestionInjector {
    public init() {}

    public struct ExtraInfo {
        public var didChangeContent = false
        public var didChangeCursorPosition = false
        public var modificationRanges: [String: CursorRange] = [:]
        public var modifications: [Modification] = []
        public init() {}
    }

    public func acceptSuggestion(
        intoContentWithoutSuggestion content: inout [String],
        cursorPosition: inout CursorPosition,
        completion: CodeSuggestion,
        extraInfo: inout ExtraInfo
    ) {
        extraInfo.didChangeContent = true
        extraInfo.didChangeCursorPosition = true
        let start = completion.range.start
        let end = completion.range.end
        let suggestionContent = completion.text
        let lineEnding = if let ending = content.first?.last, ending.isNewline {
            String(ending)
        } else {
            "\n"
        }

        let firstRemovedLine = content[safe: start.line]
        let lastRemovedLine = completion.replacingLines[safe: max(0, end.line - start.line)]
        let startLine = max(0, start.line)
        let endLine = max(start.line, min(end.line, content.endIndex - 1))
        if startLine < content.endIndex {
            extraInfo.modifications.append(.deleted(startLine...endLine))
            content.removeSubrange(startLine...endLine)
        }

        var toBeInserted = suggestionContent.breakLines(
            proposedLineEnding: lineEnding,
            appendLineBreakToLastLine: true
        )

        // prepending prefix text not in range if needed.
        if let firstRemovedLine,
           !firstRemovedLine.isEmptyOrNewLine,
           start.character > 0,
           start.character < firstRemovedLine.count,
           !toBeInserted.isEmpty
        {
            let leftoverRange = firstRemovedLine.utf16.startIndex..<(firstRemovedLine.utf16.index(
                firstRemovedLine.utf16.startIndex,
                offsetBy: start.character,
                limitedBy: firstRemovedLine.utf16.endIndex
            ) ?? firstRemovedLine.utf16.endIndex)
            var leftover = String(firstRemovedLine[leftoverRange])
            if leftover.last?.isNewline ?? false {
                leftover.removeLast(1)
            }
            toBeInserted[0].insert(
                contentsOf: leftover,
                at: toBeInserted[0].startIndex
            )
        }

        let recoveredSuffixLength = recoverSuffixIfNeeded(
            endOfReplacedContent: end,
            toBeInserted: &toBeInserted,
            originalLastRemovedLine: lastRemovedLine,
            lineEnding: lineEnding
        )

        let cursorCol = toBeInserted[toBeInserted.endIndex - 1].utf16.count
            - 1 - recoveredSuffixLength
        let insertingIndex = min(start.line, content.endIndex)
        content.insert(contentsOf: toBeInserted, at: insertingIndex)
        extraInfo.modifications.append(.inserted(insertingIndex, toBeInserted))
        cursorPosition = .init(
            line: startLine + toBeInserted.count - 1,
            character: max(0, cursorCol)
        )
        extraInfo.modificationRanges[completion.id] = .init(start: start, end: cursorPosition)
    }

    public func acceptSuggestions(
        intoContentWithoutSuggestion content: inout [String],
        cursorPosition: inout CursorPosition,
        completions: [CodeSuggestion],
        extraInfo: inout ExtraInfo
    ) {
        let sortedCompletions = completions.sorted {
            if $0.range.start.line < $1.range.start.line {
                true
            } else if $0.range.start.line == $1.range.start.line {
                $0.range.start.character < $1.range.start.character
            } else {
                false
            }
        }

        for var completion in sortedCompletions {
            let lineCountChange: Int = {
                var accumulation = 0
                let endIndex = completion.range.start.line
                for modification in extraInfo.modifications {
                    switch modification {
                    case let .deleted(range):
                        if range.lowerBound <= endIndex {
                            accumulation -= range.count
                            if range.upperBound >= endIndex {
                                accumulation += range.upperBound - endIndex
                            }
                        }
                    case let .inserted(index, lines):
                        if index <= endIndex {
                            accumulation += lines.count
                        }
                    }
                }
                return accumulation
            }()

            if lineCountChange != 0 {
                completion.position = CursorPosition(
                    line: completion.position.line + lineCountChange,
                    character: completion.position.character
                )
                completion.range = CursorRange(
                    start: CursorPosition(
                        line: completion.range.start.line + lineCountChange,
                        character: completion.range.start.character
                    ),
                    end: CursorPosition(
                        line: completion.range.end.line + lineCountChange,
                        character: completion.range.end.character
                    )
                )
            }

            completion.replacingLines = {
                let start = completion.range.start.line
                let end = completion.range.end.line
                if start >= content.endIndex {
                    return []
                }
                if end < content.endIndex {
                    return Array(content[start...end])
                }
                return Array(content[start...])
            }()

            // Accept the suggestion
            acceptSuggestion(
                intoContentWithoutSuggestion: &content,
                cursorPosition: &cursorPosition,
                completion: completion,
                extraInfo: &extraInfo
            )
        }
    }

    func recoverSuffixIfNeeded(
        endOfReplacedContent end: CursorPosition,
        toBeInserted: inout [String],
        originalLastRemovedLine: String?,
        lineEnding: String
    ) -> Int {
        // If there is no line removed, there is no need to recover anything.
        guard let lastRemovedLine = originalLastRemovedLine,
              !lastRemovedLine.isEmptyOrNewLine else { return 0 }

        let lastRemovedLineCleaned = lastRemovedLine.droppedLineBreak()

        // locate the split index, the prefix of which matches the suggestion prefix.
        let splitIndex = lastRemovedLineCleaned.utf16.index(
            lastRemovedLineCleaned.utf16.startIndex,
            offsetBy: end.character,
            limitedBy: lastRemovedLineCleaned.utf16.endIndex
        )

        // then check how many characters are not in the suffix of the suggestion.
        guard let splitIndex, splitIndex != lastRemovedLineCleaned.utf16.endIndex else { return 0 }

        var suffix = String(lastRemovedLineCleaned[splitIndex...])

        // remove the first adjacent placeholder in suffix which looks like `<#Hello#>`

        let regex = try! NSRegularExpression(pattern: "\\s*?<#.*?#>")

        if let firstPlaceholderRange = regex.firstMatch(
            in: suffix,
            options: [],
            range: NSRange(suffix.startIndex..., in: suffix)
        )?.range,
            firstPlaceholderRange.location == 0,
            let r = Range(firstPlaceholderRange, in: suffix)
        {
            suffix.removeSubrange(r)
        }

        let lastInsertingLine = toBeInserted[toBeInserted.endIndex - 1]
            .droppedLineBreak()
            .appending(suffix)
            .recoveredLineBreak(lineEnding: lineEnding)

        toBeInserted[toBeInserted.endIndex - 1] = lastInsertingLine

        return suffix.utf16.count
    }
}

public struct SuggestionAnalyzer {
    struct Result {
        enum InsertPostion {
            case currentLine
            case nextLine
        }

        var insertPosition: InsertPostion
        var commonPrefix: String?
    }

    func analyze() -> Result {
        fatalError()
    }
}

extension String {
    var isEmptyOrNewLine: Bool {
        isEmpty || self == "\n" || self == "\r\n" || self == "\r"
    }

    func droppedLineBreak() -> String {
        if last?.isNewline ?? false {
            return String(dropLast(1))
        }
        return self
    }

    func recoveredLineBreak(lineEnding: String) -> String {
        if hasSuffix(lineEnding) {
            return self
        }
        return self + lineEnding
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

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

