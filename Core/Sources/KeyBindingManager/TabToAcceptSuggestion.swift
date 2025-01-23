import ActiveApplicationMonitor
import AppKit
import CGEventOverride
import CommandHandler
import Dependencies
import Foundation
import Logger
import Preferences
import SuggestionBasic
import UserDefaultsObserver
import Workspace
import WorkspaceSuggestionService
import XcodeInspector

struct TabToAcceptSuggestionHandler: KeyBindingHandler {
    var canTabToAcceptSuggestion: Bool {
        UserDefaults.shared.value(for: \.acceptSuggestionWithTab)
    }

    var canEscToDismissSuggestion: Bool {
        UserDefaults.shared.value(for: \.dismissSuggestionWithEsc)
    }

    @Dependency(\.workspacePool) var workspacePool
    @Dependency(\.commandHandler) var commandHandler

    var isOn: Bool {
        canTabToAcceptSuggestion || canEscToDismissSuggestion
    }

    func handleEvent(_ event: CGEvent) -> CGEventManipulation.Result {
        let keycode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let tab = 48
        let esc = 53
        let right = 124

        switch keycode {
        case tab:
            return handleTab(event.flags)
        case esc:
            return handleEsc(event.flags)
        case right:
            return handleRight(event.flags)
        default:
            return .unchanged
        }
    }

    func handleTab(_ flags: CGEventFlags) -> CGEventManipulation.Result {
        Logger.service.info("TabToAcceptSuggestion: Tab")

        guard let fileURL = ThreadSafeAccessToXcodeInspector.shared.activeDocumentURL
        else {
            Logger.service.info("TabToAcceptSuggestion: No active document")
            return .unchanged
        }

        let language = languageIdentifierFromFileURL(fileURL)

        if flags.contains(.maskHelp) { return .unchanged }

        let requiredFlagsToTrigger: CGEventFlags = {
            var all = CGEventFlags()
            if UserDefaults.shared.value(for: \.acceptSuggestionWithModifierShift) {
                all.insert(.maskShift)
            }
            if UserDefaults.shared.value(for: \.acceptSuggestionWithModifierControl) {
                all.insert(.maskControl)
            }
            if UserDefaults.shared.value(for: \.acceptSuggestionWithModifierOption) {
                all.insert(.maskAlternate)
            }
            if UserDefaults.shared.value(for: \.acceptSuggestionWithModifierCommand) {
                all.insert(.maskCommand)
            }
            if UserDefaults.shared.value(for: \.acceptSuggestionWithModifierOnlyForSwift) {
                if language == .builtIn(.swift) {
                    return all
                } else {
                    return []
                }
            } else {
                return all
            }
        }()

        let flagsToAvoidWhenNotRequired: [CGEventFlags] = [
            .maskShift, .maskCommand, .maskHelp, .maskSecondaryFn,
        ]

        guard flags.contains(requiredFlagsToTrigger) else {
            Logger.service.info("TabToAcceptSuggestion: Modifier not found")
            return .unchanged
        }

        for flag in flagsToAvoidWhenNotRequired {
            if flags.contains(flag), !requiredFlagsToTrigger.contains(flag) {
                return .unchanged
            }
        }

        guard canTabToAcceptSuggestion else {
            Logger.service.info("TabToAcceptSuggestion: Feature not available")
            return .unchanged
        }

        guard ThreadSafeAccessToXcodeInspector.shared.activeXcode != nil
        else {
            Logger.service.info("TabToAcceptSuggestion: Xcode not found")
            return .unchanged
        }
        guard let editor = ThreadSafeAccessToXcodeInspector.shared.focusedEditor
        else {
            Logger.service.info("TabToAcceptSuggestion: No editor found")
            return .unchanged
        }
        guard let filespace = workspacePool.fetchFilespaceIfExisted(fileURL: fileURL)
        else {
            Logger.service.info("TabToAcceptSuggestion: No file found")
            return .unchanged
        }
        guard let presentingSuggestion = filespace.suggestionManager?
            ._mainThread_displaySuggestions.activeSuggestion?.activeCodeSuggestion,
            let manager = filespace.suggestionManager
        else {
            Logger.service.info(
                "TabToAcceptSuggestion: No Suggestions found \(filespace.fileURL.lastPathComponent)"
            )
            return .unchanged
        }

        if flags.contains(.maskAlternate) && !requiredFlagsToTrigger.contains(.maskAlternate) {
            if !UserDefaults.shared.value(for: \.switchSuggestionGroupWithTab) {
                return .unchanged
            }
            if manager._mainThread_displaySuggestions.count <= 1 {
                return .unchanged
            } else {
                Task { await commandHandler.presentNextSuggestionGroup() }
                return .discarded
            }
        } else {
            let editorContent = editor.getContent()

            let shouldAcceptSuggestion = Self.checkIfAcceptSuggestion(
                lines: editorContent.lines,
                cursorPosition: editorContent.cursorPosition,
                codeMetadata: filespace.codeMetadata,
                presentingSuggestionText: presentingSuggestion.text
            )

            if shouldAcceptSuggestion {
                Logger.service.info("TabToAcceptSuggestion: Accept")
                if flags.contains(.maskControl),
                   !requiredFlagsToTrigger.contains(.maskControl)
                {
                    if UserDefaults.shared.value(for: \.acceptSuggestionLineWithTab) {
                        Task {
                            await commandHandler.acceptActiveSuggestionLineInGroup(atIndex: nil)
                        }
                        return .discarded
                    } else {
                        return .unchanged
                    }
                } else {
                    Task { await commandHandler.acceptActiveSuggestionInGroup(atIndex: nil) }
                    return .discarded
                }
            } else {
                Logger.service.info("TabToAcceptSuggestion: Should not accept")
                return .unchanged
            }
        }
    }

    func handleEsc(_ flags: CGEventFlags) -> CGEventManipulation.Result {
        guard
            !flags.contains(.maskShift),
            !flags.contains(.maskControl),
            !flags.contains(.maskAlternate),
            !flags.contains(.maskCommand),
            !flags.contains(.maskHelp),
            canEscToDismissSuggestion
        else { return .unchanged }

        guard
            let fileURL = ThreadSafeAccessToXcodeInspector.shared.activeDocumentURL,
            ThreadSafeAccessToXcodeInspector.shared.activeXcode != nil,
            let filespace = workspacePool.fetchFilespaceIfExisted(fileURL: fileURL),
            filespace.suggestionManager?
            ._mainThread_displaySuggestions.activeSuggestion?.activeCodeSuggestion != nil
        else { return .unchanged }

        Task { await commandHandler.dismissSuggestion() }
        return .discarded
    }

    func handleRight(_ flags: CGEventFlags) -> CGEventManipulation.Result {
        guard UserDefaults.shared.value(for: \.acceptSuggestionLineWithArrowKey)
        else { return .unchanged }
        guard flags.contains(.maskCommand) else { return .unchanged }
        guard
            !flags.contains(.maskHelp),
            !flags.contains(.maskShift),
            !flags.contains(.maskControl)
        else { return .unchanged }

        guard
            let fileURL = ThreadSafeAccessToXcodeInspector.shared.activeDocumentURL,
            ThreadSafeAccessToXcodeInspector.shared.activeXcode != nil,
            let filespace = workspacePool.fetchFilespaceIfExisted(fileURL: fileURL),
            let suggestion = filespace.suggestionManager?
            ._mainThread_displaySuggestions.activeSuggestion
        else { return .unchanged }

        switch suggestion {
        case .action:
            return .unchanged
        case .group:
            if flags.contains(.maskAlternate) {
                Task { await commandHandler.acceptActiveSuggestionLineInGroup(atIndex: nil) }
                return .discarded
            } else {
                Task { await commandHandler.acceptActiveSuggestionNextWordInGroup(atIndex: nil) }
                return .discarded
            }
        }
    }

    static func checkIfAcceptSuggestion(
        lines: [String],
        cursorPosition: CursorPosition,
        codeMetadata: FilespaceCodeMetadata,
        presentingSuggestionText: String
    ) -> Bool {
        let line = cursorPosition.line
        guard line >= 0, line < lines.endIndex else {
            return true
        }
        let col = cursorPosition.character
        let prefixEndIndex = lines[line].utf16.index(
            lines[line].utf16.startIndex,
            offsetBy: col,
            limitedBy: lines[line].utf16.endIndex
        ) ?? lines[line].utf16.endIndex
        let prefix = String(lines[line][..<prefixEndIndex])
        let contentAfterTab = {
            let indentSize = codeMetadata.indentSize ?? 4
            if codeMetadata.usesTabsForIndentation ?? false {
                return prefix + "\t"
            } else {
                return prefix + String(repeating: " ", count: indentSize)
            }
        }()

        // If entering a tab doesn't invalidate the suggestion, just let the user type the tab.
        // else, accept the suggestion and discard the tab.
        guard !presentingSuggestionText.hasPrefix(contentAfterTab) else {
            Logger.service.info("TabToAcceptSuggestion: Space for tab")
            return false
        }
        return true
    }
}

