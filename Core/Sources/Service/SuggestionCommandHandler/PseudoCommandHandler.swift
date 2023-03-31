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

    func generateRealtimeSuggestions() async {
        guard let editor = await getEditorContent() else {
            try? await Environment.triggerAction("Prefetch Suggestions")
            return
        }
        let mode = UserDefaults.shared.value(for: \.suggestionPresentationMode)
        let handler: SuggestionCommandHandler = {
            switch mode {
            case .comment:
                return CommentBaseCommandHandler()
            case .floatingWidget:
                return WindowBaseCommandHandler()
            }
        }()
        _ = try? await handler.generateRealtimeSuggestions(editor: editor)
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

    func acceptSuggestion() async {
        if UserDefaults.shared.value(for: \.acceptSuggestionWithAccessibilityAPI) {
            guard let xcode = ActiveApplicationMonitor.activeXcode else { return }
            let application = AXUIElementCreateApplication(xcode.processIdentifier)
            guard let focusElement = application.focusedElement,
                  focusElement.description == "Source Editor"
            else { return }
            guard let (content, lines, cursorPosition) = await getFileContent() else {
                PresentInWindowSuggestionPresenter()
                    .presentErrorMessage("Unable to get file content.")
                return
            }
            let handler = CommentBaseCommandHandler()
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

                let error = AXUIElementSetAttributeValue(
                    focusElement,
                    kAXValueAttribute as CFString,
                    result.content as CFTypeRef
                )

                if error != AXError.success {
                    PresentInWindowSuggestionPresenter()
                        .presentErrorMessage("Fail to set editor content.")
                }

                if let oldPosition {
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

private extension PseudoCommandHandler {
    func getFileContent() async
        -> (content: String, lines: [String], cursorPosition: CursorPosition)?
    {
        guard let xcode = ActiveApplicationMonitor.activeXcode
            ?? ActiveApplicationMonitor.latestXcode else { return nil }
        let application = AXUIElementCreateApplication(xcode.processIdentifier)
        guard let focusElement = application.focusedElement,
              focusElement.description == "Source Editor"
        else { return nil }
        guard let selectionRange = focusElement.selectedTextRange else { return nil }
        let content = focusElement.value
        let split = content.breakLines()
        let selectedPosition = selectionRange.upperBound
        // find row and col from content at selected position
        var rowIndex = 0
        var count = 0
        var colIndex = 0
        for (i, row) in split.enumerated() {
            if count + row.count > selectedPosition {
                rowIndex = i
                colIndex = selectedPosition - count
                break
            }
            count += row.count
        }
        return (content, split, CursorPosition(line: rowIndex, character: colIndex))
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
    func getEditorContent() async -> EditorContent? {
        guard
            let filespace = await getFilespace(),
            let content = await getFileContent()
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
            selections: [],
            tabSize: tabSize,
            indentSize: indentSize,
            usesTabsForIndentation: usesTabsForIndentation
        )
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
