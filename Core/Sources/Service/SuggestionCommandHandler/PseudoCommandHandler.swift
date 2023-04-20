import ActiveApplicationMonitor
import AppKit
import CopilotModel
import Environment
import Preferences
import SuggestionInjector
import XPCShared

/// It's used to run some commands without really triggering the menu bar item.
///
/// For example, we can use it to generate real-time suggestions without Apple Scripts.
struct PseudoCommandHandler {
    func presentPreviousSuggestion() async {
        let handler = WindowBaseCommandHandler()
        _ = try? await handler.presentPreviousSuggestion(editor: .init(
            content: "",
            lines: [],
            uti: "",
            cursorPosition: .outOfScope,
            selections: [],
            tabSize: 0,
            indentSize: 0,
            usesTabsForIndentation: false
        ))
    }

    func presentNextSuggestion() async {
        let handler = WindowBaseCommandHandler()
        _ = try? await handler.presentNextSuggestion(editor: .init(
            content: "",
            lines: [],
            uti: "",
            cursorPosition: .outOfScope,
            selections: [],
            tabSize: 0,
            indentSize: 0,
            usesTabsForIndentation: false
        ))
    }

    func generateRealtimeSuggestions(sourceEditor: AXUIElement?) async {
        // Can't use handler if content is not available.
        guard let editor = await getEditorContent(sourceEditor: sourceEditor) else { return }

        // Otherwise, get it from pseudo handler directly.
        let mode = UserDefaults.shared.value(for: \.suggestionPresentationMode)
        switch mode {
        case .comment:
            let handler = CommentBaseCommandHandler()
            _ = try? await handler.generateRealtimeSuggestions(editor: editor)
        case .floatingWidget:
            let handler = WindowBaseCommandHandler()
            _ = try? await handler.generateRealtimeSuggestions(editor: editor)
        }
    }

    func rejectSuggestions() async {
        let handler = WindowBaseCommandHandler()
        _ = try? await handler.rejectSuggestion(editor: .init(
            content: "",
            lines: [],
            uti: "",
            cursorPosition: .outOfScope,
            selections: [],
            tabSize: 0,
            indentSize: 0,
            usesTabsForIndentation: false
        ))
    }

    func handleCustomDomain(name: String) async {
        guard let editor = await getEditorContent(sourceEditor: nil)
        else {
            do {
                try await Environment.triggerAction(name)
            } catch {
                let presenter = PresentInWindowSuggestionPresenter()
                presenter.presentError(error)
            }
            return
        }

        let handler = WindowBaseCommandHandler()
        do {
            try await handler.handleCustomCommand(name: name, editor: editor)
        } catch {
            let presenter = PresentInWindowSuggestionPresenter()
            presenter.presentError(error)
        }
    }

    func acceptSuggestion() async {
        if UserDefaults.shared.value(for: \.acceptSuggestionWithAccessibilityAPI) {
            guard let xcode = ActiveApplicationMonitor.activeXcode ?? ActiveApplicationMonitor
                .latestXcode else { return }
            let application = AXUIElementCreateApplication(xcode.processIdentifier)
            guard let focusElement = application.focusedElement,
                  focusElement.description == "Source Editor"
            else { return }
            guard let (content, lines, _, cursorPosition) = await getFileContent(sourceEditor: nil)
            else {
                PresentInWindowSuggestionPresenter()
                    .presentErrorMessage("Unable to get file content.")
                return
            }
            let handler = WindowBaseCommandHandler()
            do {
                guard let result = try await handler.acceptSuggestion(editor: .init(
                    content: content,
                    lines: lines,
                    uti: "",
                    cursorPosition: cursorPosition,
                    selections: [],
                    tabSize: 0,
                    indentSize: 0,
                    usesTabsForIndentation: false
                )) else { return }

                let oldPosition = focusElement.selectedTextRange
                let oldScrollPosition = focusElement.parent?.verticalScrollBar?.doubleValue

                let error = AXUIElementSetAttributeValue(
                    focusElement,
                    kAXValueAttribute as CFString,
                    result.content as CFTypeRef
                )

                if error != AXError.success {
                    PresentInWindowSuggestionPresenter()
                        .presentErrorMessage("Fail to set editor content.")
                }

                if let selection = result.newSelection {
                    var range = convertCursorRangeToRange(selection, in: result.content)
                    if let value = AXValueCreate(.cfRange, &range) {
                        AXUIElementSetAttributeValue(
                            focusElement,
                            kAXSelectedTextRangeAttribute as CFString,
                            value
                        )
                    }
                } else if let oldPosition {
                    var range = CFRange(
                        location: oldPosition.lowerBound,
                        length: 0
                    )
                    if let value = AXValueCreate(.cfRange, &range) {
                        AXUIElementSetAttributeValue(
                            focusElement,
                            kAXSelectedTextRangeAttribute as CFString,
                            value
                        )
                    }
                }

                if let oldScrollPosition, let scrollBar = focusElement.parent?.verticalScrollBar {
                    AXUIElementSetAttributeValue(
                        scrollBar,
                        kAXValueAttribute as CFString,
                        oldScrollPosition as CFTypeRef
                    )
                }

            } catch {
                PresentInWindowSuggestionPresenter().presentError(error)
            }
        } else {
            do {
                try await Environment.triggerAction("Accept Suggestion")
                return
            } catch {
                PresentInWindowSuggestionPresenter().presentError(error)
            }
        }
    }
}

extension PseudoCommandHandler {
    func getFileContent(sourceEditor: AXUIElement?) async
        -> (
            content: String,
            lines: [String],
            selections: [CursorRange],
            cursorPosition: CursorPosition
        )?
    {
        guard let xcode = ActiveApplicationMonitor.activeXcode
            ?? ActiveApplicationMonitor.latestXcode else { return nil }
        let application = AXUIElementCreateApplication(xcode.processIdentifier)
        guard let focusElement = sourceEditor ?? application.focusedElement,
              focusElement.description == "Source Editor"
        else { return nil }
        guard let selectionRange = focusElement.selectedTextRange else { return nil }
        let content = focusElement.value
        let split = content.breakLines()
        let range = convertRangeToCursorRange(selectionRange, in: content)
        return (content, split, [range], range.end)
    }

    func getFileURL() async -> URL? {
        try? await Environment.fetchCurrentFileURL()
    }

    @ServiceActor
    func getFilespace() async -> Filespace? {
        guard
            let fileURL = await getFileURL(),
            let (_, filespace) = try? await Workspace
            .fetchOrCreateWorkspaceIfNeeded(fileURL: fileURL)
        else { return nil }
        return filespace
    }

    @ServiceActor
    func getEditorContent(sourceEditor: AXUIElement?) async -> EditorContent? {
        guard
            let filespace = await getFilespace(),
            let content = await getFileContent(sourceEditor: sourceEditor)
        else { return nil }
        let uti = filespace.uti ?? ""
        let tabSize = filespace.tabSize ?? 4
        let indentSize = filespace.indentSize ?? 4
        let usesTabsForIndentation = filespace.usesTabsForIndentation ?? false
        return .init(
            content: content.content,
            lines: content.lines,
            uti: uti,
            cursorPosition: content.cursorPosition,
            selections: content.selections.map {
                .init(start: $0.start, end: $0.end)
            },
            tabSize: tabSize,
            indentSize: indentSize,
            usesTabsForIndentation: usesTabsForIndentation
        )
    }

    func convertCursorRangeToRange(
        _ cursorRange: CursorRange,
        in content: String
    ) -> CFRange {
        let lines = content.breakLines()
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

    func convertRangeToCursorRange(
        _ range: ClosedRange<Int>,
        in content: String
    ) -> CursorRange {
        let lines = content.breakLines()
        guard !lines.isEmpty else { return CursorRange(start: .zero, end: .zero) }
        var countS = 0
        var countE = 0
        var cursorRange = CursorRange(start: .zero, end: .outOfScope)
        for (i, line) in lines.enumerated() {
            if countS <= range.lowerBound && range.lowerBound < countS + line.count {
                cursorRange.start = .init(line: i, character: range.lowerBound - countS)
            }
            if countE <= range.upperBound && range.upperBound < countE + line.count {
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
}

public extension String {
    /// Break a string into lines.
    func breakLines() -> [String] {
        let lines = split(separator: "\n", omittingEmptySubsequences: false)
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
