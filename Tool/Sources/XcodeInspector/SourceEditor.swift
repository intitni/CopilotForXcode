import AppKit
import AsyncExtensions
import AXNotificationStream
import Foundation
import SuggestionModel

/// Representing a source editor inside Xcode.
public class SourceEditor {
    public typealias Content = EditorInformation.SourceEditorContent

    public struct AXNotification {
        public var kind: AXNotificationKind
        public var element: AXUIElement
    }

    public enum AXNotificationKind {
        case selectedTextChanged
        case valueChanged
        case scrollPositionChanged
    }

    let runningApplication: NSRunningApplication
    public let element: AXUIElement
    var observeAXNotificationsTask: Task<Void, Never>?
    public let axNotifications = AsyncPassthroughSubject<AXNotification>()

    /// The content of the source editor.
    public var content: Content {
        let content = element.value
        let split = content.breakLines(appendLineBreakToLastLine: false)
        let lineAnnotationElements = element.children.filter { $0.identifier == "Line Annotation" }
        let lineAnnotations = lineAnnotationElements.map(\.description)

        if let selectionRange = element.selectedTextRange {
            let range = Self.convertRangeToCursorRange(selectionRange, in: split)
            return .init(
                content: content,
                lines: split,
                selections: [range],
                cursorPosition: range.start,
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
        observeAXNotifications()
    }

    private func observeAXNotifications() {
        observeAXNotificationsTask?.cancel()
        observeAXNotificationsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await withThrowingTaskGroup(of: Void.self) { [weak self] group in
                guard let self else { return }
                let editorNotifications = AXNotificationStream(
                    app: runningApplication,
                    element: element,
                    notificationNames:
                    kAXSelectedTextChangedNotification,
                    kAXValueChangedNotification
                )

                group.addTask { [weak self] in
                    for await notification in editorNotifications {
                        try Task.checkCancellation()
                        guard let self else { return }
                        if let kind: AXNotificationKind = {
                            switch notification.name {
                            case kAXSelectedTextChangedNotification: return .selectedTextChanged
                            case kAXValueChangedNotification: return .valueChanged
                            default: return nil
                            }
                        }() {
                            self.axNotifications.send(.init(
                                kind: kind,
                                element: notification.element
                            ))
                        }
                    }
                }

                if let scrollView = element.parent, let scrollBar = scrollView.verticalScrollBar {
                    let scrollViewNotifications = AXNotificationStream(
                        app: runningApplication,
                        element: scrollBar,
                        notificationNames: kAXValueChangedNotification
                    )

                    group.addTask { [weak self] in
                        for await notification in scrollViewNotifications {
                            try Task.checkCancellation()
                            guard let self else { return }
                            self.axNotifications.send(.init(
                                kind: .scrollPositionChanged,
                                element: notification.element
                            ))
                        }
                    }
                }

                try? await group.waitForAll()
            }
        }
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
        let lines = content.breakLines(appendLineBreakToLastLine: false)
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
            // The range is counted in UTF8, which causes line endings like \r\n to be of length 2.
            let lineEndingAddition = (line.lineEnding?.utf8.count ?? 1) - 1
            if countS <= range.lowerBound,
               range.lowerBound < countS + line.count + lineEndingAddition
            {
                cursorRange.start = .init(line: i, character: range.lowerBound - countS)
            }
            if countE <= range.upperBound,
               range.upperBound < countE + line.count + lineEndingAddition
            {
                cursorRange.end = .init(line: i, character: range.upperBound - countE)
                break
            }
            countS += line.count + lineEndingAddition
            countE += line.count + lineEndingAddition
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
        let lines = content.breakLines(appendLineBreakToLastLine: false)
        return convertRangeToCursorRange(range, in: lines)
    }
}

