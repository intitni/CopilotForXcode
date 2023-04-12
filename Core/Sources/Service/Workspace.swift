import ChatService
import CopilotModel
import CopilotService
import Environment
import Foundation
import Preferences
import SuggestionInjector
import XPCShared

@ServiceActor
final class Filespace {
    struct Snapshot: Equatable {
        var linesHash: Int
        var cursorPosition: CursorPosition
    }

    let fileURL: URL
    private(set) lazy var language: String = languageIdentifierFromFileURL(fileURL).rawValue
    var suggestions: [CopilotCompletion] = [] {
        didSet { lastSuggestionUpdateTime = Environment.now() }
    }

    // stored for pseudo command handler
    var uti: String?
    var tabSize: Int?
    var indentSize: Int?
    var usesTabsForIndentation: Bool?
    // ---------------------------------

    var suggestionIndex: Int = 0
    var suggestionSourceSnapshot: Snapshot = .init(linesHash: -1, cursorPosition: .outOfScope)
    var presentingSuggestion: CopilotCompletion? {
        guard suggestions.endIndex > suggestionIndex, suggestionIndex >= 0 else { return nil }
        return suggestions[suggestionIndex]
    }

    private(set) var lastSuggestionUpdateTime: Date = Environment.now()
    var isExpired: Bool {
        Environment.now().timeIntervalSince(lastSuggestionUpdateTime) > 60 * 60 * 8
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func reset(resetSnapshot: Bool = true) {
        suggestions = []
        suggestionIndex = 0
        if resetSnapshot {
            suggestionSourceSnapshot = .init(linesHash: -1, cursorPosition: .outOfScope)
        }
    }
}

@ServiceActor
final class Workspace {
    class UserDefaultsObserver: NSObject {
        var onChange: (() -> Void)?

        override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            onChange?()
        }
    }
    
    struct SuggestionFeatureDisabledError: Error, LocalizedError {
        var errorDescription: String? {
            "Suggestion feature is disabled for this project."
        }
    }

    let projectRootURL: URL
    var lastTriggerDate = Environment.now()
    var isExpired: Bool {
        Environment.now().timeIntervalSince(lastTriggerDate) > 60 * 60 * 8
    }

    private(set) var filespaces = [URL: Filespace]()
    var isRealtimeSuggestionEnabled: Bool {
        UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
    }

    var realtimeSuggestionRequests = Set<Task<Void, Error>>()
    let userDefaultsObserver = UserDefaultsObserver()

    private var _copilotSuggestionService: CopilotSuggestionServiceType?

    private var copilotSuggestionService: CopilotSuggestionServiceType? {
        // Check if the workspace is disabled.
        let isSuggestionDisabledGlobally = UserDefaults.shared
            .value(for: \.disableSuggestionFeatureGlobally)
        if isSuggestionDisabledGlobally {
            let enabledList = UserDefaults.shared.value(for: \.suggestionFeatureEnabledProjectList)
            if !enabledList.contains(where: { path in projectRootURL.path.hasPrefix(path) }) {
                // If it's disable, remove the service
                _copilotSuggestionService = nil
                return nil
            }
        }

        if _copilotSuggestionService == nil {
            _copilotSuggestionService = Environment.createSuggestionService(projectRootURL)
        }
        return _copilotSuggestionService
    }
    
    var isSuggestionFeatureEnabled: Bool {
        copilotSuggestionService != nil
    }

    private init(projectRootURL: URL) {
        self.projectRootURL = projectRootURL
        
        Task {
            userDefaultsObserver.onChange = { [weak self] in
                guard let self else { return }
                _ = self.copilotSuggestionService
            }

            UserDefaults.shared.addObserver(
                userDefaultsObserver,
                forKeyPath: UserDefaultPreferenceKeys().suggestionFeatureEnabledProjectList.key,
                options: .new,
                context: nil
            )
            
            UserDefaults.shared.addObserver(
                userDefaultsObserver,
                forKeyPath: UserDefaultPreferenceKeys().disableSuggestionFeatureGlobally.key,
                options: .new,
                context: nil
            )
        }
    }

    func canAutoTriggerGetSuggestions(
        forFileAt fileURL: URL,
        lines: [String],
        cursorPosition: CursorPosition
    ) -> Bool {
        guard isRealtimeSuggestionEnabled else { return false }
        guard let filespace = filespaces[fileURL] else { return true }
        if lines.hashValue != filespace.suggestionSourceSnapshot.linesHash { return true }
        if cursorPosition != filespace.suggestionSourceSnapshot.cursorPosition { return true }
        return false
    }

    static func fetchOrCreateWorkspaceIfNeeded(fileURL: URL) async throws
        -> (workspace: Workspace, filespace: Filespace)
    {
        // never create duplicated filespaces
        for workspace in workspaces.values {
            if let filespace = workspace.filespaces[fileURL] {
                return (workspace, filespace)
            }
        }
        
        let projectURL = try await Environment.fetchCurrentProjectRootURL(fileURL)
        let workspaceURL = projectURL ?? fileURL
        let workspace = workspaces[workspaceURL] ?? Workspace(projectRootURL: workspaceURL)
        let filespace = workspace.filespaces[fileURL] ?? .init(fileURL: fileURL)
        if workspace.filespaces[fileURL] == nil {
            workspace.filespaces[fileURL] = filespace
        }
        workspaces[workspaceURL] = workspace
        return (workspace, filespace)
    }
}

extension Workspace {
    @discardableResult
    func generateSuggestions(
        forFileAt fileURL: URL,
        editor: EditorContent,
        shouldcancelInFlightRealtimeSuggestionRequests: Bool = true
    ) async throws -> [CopilotCompletion] {
        if shouldcancelInFlightRealtimeSuggestionRequests {
            cancelInFlightRealtimeSuggestionRequests()
        }
        lastTriggerDate = Environment.now()

        let filespace = filespaces[fileURL] ?? .init(fileURL: fileURL)
        if filespaces[fileURL] == nil {
            filespaces[fileURL] = filespace
        }

        if !editor.uti.isEmpty {
            filespace.uti = editor.uti
            filespace.tabSize = editor.tabSize
            filespace.indentSize = editor.indentSize
            filespace.usesTabsForIndentation = editor.usesTabsForIndentation
        }

        let snapshot = Filespace.Snapshot(
            linesHash: editor.lines.hashValue,
            cursorPosition: editor.cursorPosition
        )

        filespace.suggestionSourceSnapshot = snapshot

        guard let copilotSuggestionService else { throw SuggestionFeatureDisabledError() }
        let completions = try await copilotSuggestionService.getCompletions(
            fileURL: fileURL,
            content: editor.lines.joined(separator: ""),
            cursorPosition: editor.cursorPosition,
            tabSize: editor.tabSize,
            indentSize: editor.indentSize,
            usesTabsForIndentation: editor.usesTabsForIndentation,
            ignoreSpaceOnlySuggestions: true
        )

        filespace.suggestions = completions
        filespace.suggestionIndex = 0

        return completions
    }

    func selectNextSuggestion(forFileAt fileURL: URL) {
        cancelInFlightRealtimeSuggestionRequests()
        lastTriggerDate = Environment.now()
        guard let filespace = filespaces[fileURL],
              filespace.suggestions.count > 1
        else { return }
        filespace.suggestionIndex += 1
        if filespace.suggestionIndex >= filespace.suggestions.endIndex {
            filespace.suggestionIndex = 0
        }
    }

    func selectPreviousSuggestion(forFileAt fileURL: URL) {
        cancelInFlightRealtimeSuggestionRequests()
        lastTriggerDate = Environment.now()
        guard let filespace = filespaces[fileURL],
              filespace.suggestions.count > 1
        else { return }
        filespace.suggestionIndex -= 1
        if filespace.suggestionIndex < 0 {
            filespace.suggestionIndex = filespace.suggestions.endIndex - 1
        }
    }

    func rejectSuggestion(forFileAt fileURL: URL, editor: EditorContent?) {
        cancelInFlightRealtimeSuggestionRequests()
        lastTriggerDate = Environment.now()

        if let editor, !editor.uti.isEmpty {
            filespaces[fileURL]?.uti = editor.uti
            filespaces[fileURL]?.tabSize = editor.tabSize
            filespaces[fileURL]?.indentSize = editor.indentSize
            filespaces[fileURL]?.usesTabsForIndentation = editor.usesTabsForIndentation
        }
        Task {
            await copilotSuggestionService?.notifyRejected(filespaces[fileURL]?.suggestions ?? [])
        }
        filespaces[fileURL]?.reset(resetSnapshot: false)
    }

    func acceptSuggestion(forFileAt fileURL: URL, editor: EditorContent?) -> CopilotCompletion? {
        cancelInFlightRealtimeSuggestionRequests()
        lastTriggerDate = Environment.now()
        guard let filespace = filespaces[fileURL],
              !filespace.suggestions.isEmpty,
              filespace.suggestionIndex >= 0,
              filespace.suggestionIndex < filespace.suggestions.endIndex
        else { return nil }

        if let editor, !editor.uti.isEmpty {
            filespaces[fileURL]?.uti = editor.uti
            filespaces[fileURL]?.tabSize = editor.tabSize
            filespaces[fileURL]?.indentSize = editor.indentSize
            filespaces[fileURL]?.usesTabsForIndentation = editor.usesTabsForIndentation
        }

        var allSuggestions = filespace.suggestions
        let suggestion = allSuggestions.remove(at: filespace.suggestionIndex)

        Task {
            await copilotSuggestionService?.notifyAccepted(suggestion)
            await copilotSuggestionService?.notifyRejected(allSuggestions)
        }

        filespaces[fileURL]?.reset()

        return suggestion
    }
}

extension Workspace {
    func cleanUp() {
        for (fileURL, filespace) in filespaces {
            if filespace.isExpired {
                filespaces[fileURL] = nil
            }
        }
    }

    func cancelInFlightRealtimeSuggestionRequests() {
        for task in realtimeSuggestionRequests {
            task.cancel()
        }
        realtimeSuggestionRequests = []
    }
}
