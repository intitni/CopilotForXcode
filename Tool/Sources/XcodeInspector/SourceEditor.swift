import AppKit
import AsyncPassthroughSubject
import AXNotificationStream
import Foundation
import Logger
import SuggestionBasic

/// Representing a source editor inside Xcode.
public class SourceEditor {
    public typealias Content = EditorInformation.SourceEditorContent

    public struct AXNotification: Hashable {
        public var kind: AXNotificationKind
        public var element: AXUIElement

        public func hash(into hasher: inout Hasher) {
            kind.hash(into: &hasher)
        }
    }

    public enum AXNotificationKind: Hashable, Equatable {
        case selectedTextChanged
        case valueChanged
        case scrollPositionChanged
        case evaluatedContentChanged
    }

    let runningApplication: NSRunningApplication
    public let element: AXUIElement
    var observeAXNotificationsTask: Task<Void, Never>?
    public let axNotifications = AsyncPassthroughSubject<AXNotification>()

    /// To prevent expensive calculations in ``getContent()``.
    private let cache = Cache()
    
    public func getLatestEvaluatedContent() -> Content {
        let selectionRange = element.selectedTextRange
        let (content, lines, selections) = cache.latest()
        let lineAnnotationElements = element.children.filter { $0.identifier == "Line Annotation" }
        let lineAnnotations = lineAnnotationElements.map(\.description)

        return .init(
            content: content,
            lines: lines,
            selections: selections,
            cursorPosition: selections.first?.start ?? .outOfScope,
            cursorOffset: selectionRange?.lowerBound ?? 0,
            lineAnnotations: lineAnnotations
        )
    }

    /// Get the content of the source editor.
    ///
    /// - note: This method is expensive. It needs to convert index based ranges to line based
    /// ranges.
    public func getContent() -> Content {
        let content = element.value
        let selectionRange = element.selectedTextRange
        let (lines, selections) = cache.get(content: content, selectedTextRange: selectionRange)

        let lineAnnotationElements = element.children.filter { $0.identifier == "Line Annotation" }
        let lineAnnotations = lineAnnotationElements.map(\.description)

        axNotifications.send(.init(kind: .evaluatedContentChanged, element: element))

        return .init(
            content: content,
            lines: lines,
            selections: selections,
            cursorPosition: selections.first?.start ?? .outOfScope,
            cursorOffset: selectionRange?.lowerBound ?? 0,
            lineAnnotations: lineAnnotations
        )
    }

    public init(runningApplication: NSRunningApplication, element: AXUIElement) {
        self.runningApplication = runningApplication
        self.element = element
        element.setMessagingTimeout(2)
        observeAXNotifications()
    }

    private func observeAXNotifications() {
        observeAXNotificationsTask?.cancel()
        observeAXNotificationsTask = Task { @XcodeInspectorActor [weak self] in
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
                        await Task.yield()
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
                            await Task.yield()
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

extension SourceEditor {
    final class Cache {
        static let queue = DispatchQueue(label: "SourceEditor.Cache")

        private var sourceContent: String?
        private var cachedLines = [String]()
        private var sourceSelectedTextRange: ClosedRange<Int>?
        private var cachedSelections = [CursorRange]()

        init(
            sourceContent: String? = nil,
            cachedLines: [String] = [String](),
            sourceSelectedTextRange: ClosedRange<Int>? = nil,
            cachedSelections: [CursorRange] = [CursorRange]()
        ) {
            self.sourceContent = sourceContent
            self.cachedLines = cachedLines
            self.sourceSelectedTextRange = sourceSelectedTextRange
            self.cachedSelections = cachedSelections
        }

        func get(content: String, selectedTextRange: ClosedRange<Int>?) -> (
            lines: [String],
            selections: [CursorRange]
        ) {
            Self.queue.sync {
                let contentMatch = content == sourceContent
                let selectedRangeMatch = selectedTextRange == sourceSelectedTextRange
                let lines: [String] = {
                    if contentMatch {
                        return cachedLines
                    }
                    return content.breakLines(appendLineBreakToLastLine: false)
                }()
                let selections: [CursorRange] = {
                    if contentMatch, selectedRangeMatch {
                        return cachedSelections
                    }
                    if let selectedTextRange {
                        return [SourceEditor.convertRangeToCursorRange(
                            selectedTextRange,
                            in: lines
                        )]
                    }
                    return []
                }()

                sourceContent = content
                cachedLines = lines
                sourceSelectedTextRange = selectedTextRange
                cachedSelections = selections

                return (lines, selections)
            }
        }
        
        func latest() -> (content: String, lines: [String], selections: [CursorRange]) {
            Self.queue.sync {
                (sourceContent ?? "", cachedLines, cachedSelections)
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
            countS += line.utf16.count
            countE += line.utf16.count
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
            if countS <= range.lowerBound,
               range.lowerBound < countS + line.utf16.count
            {
                cursorRange.start = .init(line: i, character: range.lowerBound - countS)
            }
            if countE <= range.upperBound,
               range.upperBound < countE + line.utf16.count
            {
                cursorRange.end = .init(line: i, character: range.upperBound - countE)
                break
            }
            countS += line.utf16.count
            countE += line.utf16.count
        }
        if cursorRange.end == .outOfScope {
            cursorRange.end = .init(
                line: lines.endIndex - 1,
                character: lines.last?.utf16.count ?? 0
            )
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

