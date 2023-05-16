import AppKit
import AXNotificationStream
import Foundation
import SuggestionModel

/// Representing a source editor inside Xcode.
public class SourceEditor {
    public struct Content {
        /// The content of the source editor.
        var content: String
        /// The content of the source editor in lines.
        var lines: [String]
        /// The selection ranges of the source editor.
        var selections: [CursorRange]
        /// The cursor position of the source editor.
        var cursorPosition: CursorPosition
        /// Line annotations of the source editor.
        var lineAnnotations: [String]
    }

    let runningApplication: NSRunningApplication
    let element: AXUIElement

    /// The content of the source editor.
    public var content: Content {
        let content = element.value
        let split = Self.breakLines(content)
        let lineAnnotationElements = element.children { $0.identifier == "Line Annotation" }
        let lineAnnotations = lineAnnotationElements.map(\.label)

        if let selectionRange = element.selectedTextRange {
            let range = Self.convertRangeToCursorRange(selectionRange, in: content)
            return .init(
                content: content,
                lines: split,
                selections: [range],
                cursorPosition: range.end,
                lineAnnotations: lineAnnotations
            )
        }
        return .init(
            content: content,
            lines: split,
            selections: [],
            cursorPosition: .outOfScope,
            lineAnnotations: lineAnnotations
        )
    }

    public init(runningApplication: NSRunningApplication, element: AXUIElement) {
        self.runningApplication = runningApplication
        self.element = element
    }

    /// Observe to changes in the source editor.
    public func observe(notificationNames: String...) -> AXNotificationStream {
        return AXNotificationStream(
            app: runningApplication,
            element: element,
            notificationNames: notificationNames
        )
    }

    /// Observe to changes in the source editor scroll view.
    public func observeScrollView(notificationNames: String...) -> AXNotificationStream? {
        guard let scrollView = element.parent else { return nil }
        return AXNotificationStream(
            app: runningApplication,
            element: scrollView,
            notificationNames: notificationNames
        )
    }
}

// MARK: - Helpers

public extension SourceEditor {
    static func convertCursorRangeToRange(
        _ cursorRange: CursorRange,
        in lines: [String]
    ) -> CFRange {
        var countS = 0
        var countE = 0
        var range = CFRange(location: 0, length: 0)
        for (i, line) in lines.enumerated() {
            if i == cursorRange.start.line {
                countS = countS + cursorRange.start.character
                range.location = countS
            }
            if i == cursorRange.end.line {
                countE = countE + cursorRange.end.character
                range.length = max(countE - range.location, 0)
                break
            }
            countS += line.count
            countE += line.count
        }
        return range
    }

    static func convertCursorRangeToRange(
        _ cursorRange: CursorRange,
        in content: String
    ) -> CFRange {
        let lines = breakLines(content)
        return convertCursorRangeToRange(cursorRange, in: lines)
    }

    static func convertRangeToCursorRange(
        _ range: ClosedRange<Int>,
        in lines: [String]
    ) -> CursorRange {
        guard !lines.isEmpty else { return CursorRange(start: .zero, end: .zero) }
        var countS = 0
        var countE = 0
        var cursorRange = CursorRange(start: .zero, end: .outOfScope)
        for (i, line) in lines.enumerated() {
            if countS <= range.lowerBound, range.lowerBound < countS + line.count {
                cursorRange.start = .init(line: i, character: range.lowerBound - countS)
            }
            if countE <= range.upperBound, range.upperBound < countE + line.count {
                cursorRange.end = .init(line: i, character: range.upperBound - countE)
                break
            }
            countS += line.count
            countE += line.count
        }
        if cursorRange.end == .outOfScope {
            cursorRange.end = .init(line: lines.endIndex - 1, character: lines.last?.count ?? 0)
        }
        return cursorRange
    }

    static func convertRangeToCursorRange(
        _ range: ClosedRange<Int>,
        in content: String
    ) -> CursorRange {
        let lines = breakLines(content)
        return convertRangeToCursorRange(range, in: lines)
    }

    static func breakLines(_ string: String) -> [String] {
        let lines = string.split(separator: "\n", omittingEmptySubsequences: false)
        var all = [String]()
        for (index, line) in lines.enumerated() {
            if index == lines.endIndex - 1 {
                all.append(String(line))
            } else {
                all.append(String(line) + "\n")
            }
        }
        return all
    }
}

