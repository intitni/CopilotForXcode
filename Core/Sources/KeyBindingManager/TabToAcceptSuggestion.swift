import ActiveApplicationMonitor
import AppKit
import CGEventOverride
import Foundation
import Logger
import Preferences
import SuggestionBasic
import UserDefaultsObserver
import Workspace
import XcodeInspector

final class TabToAcceptSuggestion {
    let hook: CGEventHookType = CGEventHook(eventsOfInterest: [.keyDown]) { message in
        Logger.service.debug("TabToAcceptSuggestion: \(message)")
    }

    let workspacePool: WorkspacePool
    let acceptSuggestion: () -> Void
    let dismissSuggestion: () -> Void
    private var CGEventObservationTask: Task<Void, Error>?
    private var isObserving: Bool { CGEventObservationTask != nil }
    private let userDefaultsObserver = UserDefaultsObserver(
        object: UserDefaults.shared, forKeyPaths: [
            UserDefaultPreferenceKeys().acceptSuggestionWithTab.key,
            UserDefaultPreferenceKeys().dismissSuggestionWithEsc.key,
        ], context: nil
    )
    private var stoppedForExit = false

    struct ObservationKey: Hashable {}

    var canTapToAcceptSuggestion: Bool {
       UserDefaults.shared.value(for: \.acceptSuggestionWithTab)
    }

    var canEscToDismissSuggestion: Bool {
        UserDefaults.shared.value(for: \.dismissSuggestionWithEsc)
    }

    @MainActor
    func stopForExit() {
        Logger.debug.info("TabToAcceptSuggestion: stopForExit")
        stoppedForExit = true
        stopObservation()
    }

    init(
        workspacePool: WorkspacePool,
        acceptSuggestion: @escaping () -> Void,
        dismissSuggestion: @escaping () -> Void
    ) {
        _ = ThreadSafeAccessToXcodeInspector.shared
        self.workspacePool = workspacePool
        self.acceptSuggestion = acceptSuggestion
        self.dismissSuggestion = dismissSuggestion

        hook.add(
            .init(
                eventsOfInterest: [.keyDown],
                convert: { [weak self] _, _, event in
                    self?.handleEvent(event) ?? .unchanged
                }
            ),
            forKey: ObservationKey()
        )
    }

    func start() {
        Logger.debug.info("TabToAcceptSuggestion: start")
        Task { [weak self] in
            for await _ in ActiveApplicationMonitor.shared.createInfoStream() {
                guard let self else { return }
                try Task.checkCancellation()
                Logger.debug.info("TabToAcceptSuggestion: Active app changed")
                Task { @MainActor in
                    if ActiveApplicationMonitor.shared.activeXcode != nil {
                        self.startObservation()
                    } else {
                        self.stopObservation()
                    }
                }
            }
        }

        userDefaultsObserver.onChange = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                Logger.debug.info("TabToAcceptSuggestion: Settings changed")
                if self.canTapToAcceptSuggestion || self.canEscToDismissSuggestion {
                    self.startObservation()
                } else {
                    self.stopObservation()
                }
            }
        }
    }

    @MainActor
    func startObservation() {
        Logger.debug.info("TabToAcceptSuggestion: startObservation")
        guard !stoppedForExit else { return }
        guard canTapToAcceptSuggestion || canEscToDismissSuggestion else { return }
        hook.activateIfPossible()
    }

    @MainActor
    func stopObservation() {
        Logger.debug.info("TabToAcceptSuggestion: stopObservation")
        hook.deactivate()
    }

    func handleEvent(_ event: CGEvent) -> CGEventManipulation.Result {
        Logger.debug.info("TabToAcceptSuggestion: handleEvent")
        let keycode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let tab = 48
        let esc = 53

        switch keycode {
        case tab:
            Logger.debug.info(
                "TabToAcceptSuggestion: Tab detected, flags: \(event.flags), permission: \(canTapToAcceptSuggestion)"
            )

            guard let fileURL = ThreadSafeAccessToXcodeInspector.shared.activeDocumentURL
            else {
                Logger.debug.info("TabToAcceptSuggestion: Active file not found")
                return .unchanged
            }

            let language = languageIdentifierFromFileURL(fileURL)

            func checkKeybinding() -> Bool {
                if event.flags.contains(.maskHelp) { return false }

                let shouldCheckModifiers = if UserDefaults.shared
                    .value(for: \.acceptSuggestionWithModifierOnlyForSwift)
                {
                    language == .builtIn(.swift)
                } else {
                    true
                }

                if shouldCheckModifiers {
                    if event.flags.contains(.maskShift) != UserDefaults.shared
                        .value(for: \.acceptSuggestionWithModifierShift)
                    {
                        return false
                    }
                    if event.flags.contains(.maskControl) != UserDefaults.shared
                        .value(for: \.acceptSuggestionWithModifierControl)
                    {
                        return false
                    }
                    if event.flags.contains(.maskAlternate) != UserDefaults.shared
                        .value(for: \.acceptSuggestionWithModifierOption)
                    {
                        return false
                    }
                    if event.flags.contains(.maskCommand) != UserDefaults.shared
                        .value(for: \.acceptSuggestionWithModifierCommand)
                    {
                        return false
                    }
                } else {
                    if event.flags.contains(.maskShift) { return false }
                    if event.flags.contains(.maskControl) { return false }
                    if event.flags.contains(.maskAlternate) { return false }
                    if event.flags.contains(.maskCommand) { return false }
                }

                return true
            }

            guard
                checkKeybinding(),
                canTapToAcceptSuggestion
            else {
                Logger.debug.info("TabToAcceptSuggestion: Tab is invalid")
                return .unchanged
            }

            guard ThreadSafeAccessToXcodeInspector.shared.activeXcode != nil
            else {
                Logger.debug.info("TabToAcceptSuggestion: Xcode not found")
                return .unchanged
            }
            guard let editor = ThreadSafeAccessToXcodeInspector.shared.focusedEditor
            else {
                Logger.debug.info("TabToAcceptSuggestion: Editor not found")
                return .unchanged
            }
            guard let filespace = workspacePool.fetchFilespaceIfExisted(fileURL: fileURL)
            else {
                Logger.debug.info("TabToAcceptSuggestion: Filespace not found: \(fileURL)")
                return .unchanged
            }
            guard let presentingSuggestion = filespace.presentingSuggestion
            else {
                Logger.debug.info("TabToAcceptSuggestion: Suggestion not found")
                return .unchanged
            }

            let editorContent = editor.getContent()

            let shouldAcceptSuggestion = Self.checkIfAcceptSuggestion(
                lines: editorContent.lines,
                cursorPosition: editorContent.cursorPosition,
                codeMetadata: filespace.codeMetadata,
                presentingSuggestionText: presentingSuggestion.text
            )

            if shouldAcceptSuggestion {
                Logger.debug.info("TabToAcceptSuggestion: Perform accept suggestion")
                acceptSuggestion()
                return .discarded
            } else {
                Logger.debug.info("TabToAcceptSuggestion: Do not accept the suggestion")
                return .unchanged
            }
        case esc:
            guard
                !event.flags.contains(.maskShift),
                !event.flags.contains(.maskControl),
                !event.flags.contains(.maskAlternate),
                !event.flags.contains(.maskCommand),
                !event.flags.contains(.maskHelp),
                canEscToDismissSuggestion
            else { return .unchanged }

            guard
                let fileURL = ThreadSafeAccessToXcodeInspector.shared.activeDocumentURL,
                ThreadSafeAccessToXcodeInspector.shared.activeXcode != nil,
                let filespace = workspacePool.fetchFilespaceIfExisted(fileURL: fileURL),
                filespace.presentingSuggestion != nil
            else { return .unchanged }

            dismissSuggestion()
            return .discarded
        default:
            return .unchanged
        }
    }
}

extension TabToAcceptSuggestion {
    static func checkIfAcceptSuggestion(
        lines: [String],
        cursorPosition: CursorPosition,
        codeMetadata: FilespaceCodeMetadata,
        presentingSuggestionText: String
    ) -> Bool {
        let line = cursorPosition.line
        guard line >= 0, line < lines.endIndex else {
            Logger.debug.info("TabToAcceptSuggestion: Suggestion position invalid")
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
            Logger.debug.info("TabToAcceptSuggestion: A tab doesn't invalidate the suggestion")
            return false
        }
        return true
    }
}

import Combine

private class ThreadSafeAccessToXcodeInspector {
    static let shared = ThreadSafeAccessToXcodeInspector()

    private(set) var activeDocumentURL: URL?
    private(set) var activeXcode: AppInstanceInspector?
    private(set) var focusedEditor: SourceEditor?
    private var cancellable: Set<AnyCancellable> = []

    init() {
        let inspector = XcodeInspector.shared

        inspector.$activeDocumentURL.receive(on: DispatchQueue.main).sink { [weak self] newValue in
            self?.activeDocumentURL = newValue
        }.store(in: &cancellable)

        inspector.$activeXcode.receive(on: DispatchQueue.main).sink { [weak self] newValue in
            self?.activeXcode = newValue
        }.store(in: &cancellable)

        inspector.$focusedEditor.receive(on: DispatchQueue.main).sink { [weak self] newValue in
            self?.focusedEditor = newValue
        }.store(in: &cancellable)
    }
}

