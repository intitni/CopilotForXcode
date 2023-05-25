import ChatService
import Environment
import Foundation
import GitHubCopilotService
import Logger
import Preferences
import SuggestionInjector
import SuggestionModel
import SuggestionService
import UserDefaultsObserver
import XcodeInspector
import XPCShared

// MARK: - Filespace

@ServiceActor
final class Filespace {
    struct Snapshot: Equatable {
        var linesHash: Int
        var cursorPosition: CursorPosition
    }

    let fileURL: URL
    private(set) lazy var language: String = languageIdentifierFromFileURL(fileURL).rawValue
    var suggestions: [CodeSuggestion] = [] {
        didSet { refreshUpdateTime() }
    }

    // stored for pseudo command handler
    var uti: String?
    var tabSize: Int?
    var indentSize: Int?
    var usesTabsForIndentation: Bool?
    // ---------------------------------

    var suggestionIndex: Int = 0
    var suggestionSourceSnapshot: Snapshot = .init(linesHash: -1, cursorPosition: .outOfScope)
    var presentingSuggestion: CodeSuggestion? {
        guard suggestions.endIndex > suggestionIndex, suggestionIndex >= 0 else { return nil }
        return suggestions[suggestionIndex]
    }

    private(set) var lastSuggestionUpdateTime: Date = Environment.now()
    var isExpired: Bool {
        Environment.now().timeIntervalSince(lastSuggestionUpdateTime) > 60 * 3
    }

    let fileSaveWatcher: FileSaveWatcher

    fileprivate init(fileURL: URL, onSave: @escaping (Filespace) -> Void) {
        self.fileURL = fileURL
        fileSaveWatcher = .init(fileURL: fileURL)
        fileSaveWatcher.changeHandler = { [weak self] in
            guard let self else { return }
            onSave(self)
        }
    }

    func reset(resetSnapshot: Bool = true) {
        suggestions = []
        suggestionIndex = 0
        if resetSnapshot {
            suggestionSourceSnapshot = .init(linesHash: -1, cursorPosition: .outOfScope)
        }
    }

    func refreshUpdateTime() {
        lastSuggestionUpdateTime = Environment.now()
    }
    
    func validateSuggestions(lines: [String], cursorPosition: CursorPosition) -> Bool {
        if cursorPosition.line != suggestionSourceSnapshot.cursorPosition.line {
            reset()
            return false
        }
        
        guard cursorPosition.line >= 0, cursorPosition.line < lines.count else {
            reset()
            return false
        }
        
        let editingLine = lines[cursorPosition.line].dropLast(1) // dropping \n
        let suggestionFirstLine = presentingSuggestion?.text.split(separator: "\n").first ?? ""
        if !suggestionFirstLine.hasPrefix(editingLine) {
            reset()
            return false
        }
        
        return true
    }
}

// MARK: - Workspace

@ServiceActor
final class Workspace {
    struct SuggestionFeatureDisabledError: Error, LocalizedError {
        var errorDescription: String? {
            "Suggestion feature is disabled for this project."
        }
    }

    let projectRootURL: URL
    let openedFileRecoverableStorage: OpenedFileRecoverableStorage
    var lastSuggestionUpdateTime = Environment.now()
    var isExpired: Bool {
        Environment.now().timeIntervalSince(lastSuggestionUpdateTime) > 60 * 60 * 4
    }

    private(set) var filespaces = [URL: Filespace]()
    var isRealtimeSuggestionEnabled: Bool {
        UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
    }

    let userDefaultsObserver = UserDefaultsObserver(
        object: UserDefaults.shared, forKeyPaths: [
            UserDefaultPreferenceKeys().suggestionFeatureEnabledProjectList.key,
            UserDefaultPreferenceKeys().disableSuggestionFeatureGlobally.key,
        ], context: nil
    )

    private var _suggestionService: SuggestionServiceType?

    private var suggestionService: SuggestionServiceType? {
        // Check if the workspace is disabled.
        let isSuggestionDisabledGlobally = UserDefaults.shared
            .value(for: \.disableSuggestionFeatureGlobally)
        if isSuggestionDisabledGlobally {
            let enabledList = UserDefaults.shared.value(for: \.suggestionFeatureEnabledProjectList)
            if !enabledList.contains(where: { path in projectRootURL.path.hasPrefix(path) }) {
                // If it's disable, remove the service
                _suggestionService = nil
                return nil
            }
        }

        if _suggestionService == nil {
            _suggestionService = Environment.createSuggestionService(projectRootURL) {
                [weak self] _ in
                guard let self else { return }
                for (_, filespace) in filespaces {
                    notifyOpenFile(filespace: filespace)
                }
            }
        }
        return _suggestionService
    }

    var isSuggestionFeatureEnabled: Bool {
        let isSuggestionDisabledGlobally = UserDefaults.shared
            .value(for: \.disableSuggestionFeatureGlobally)
        if isSuggestionDisabledGlobally {
            let enabledList = UserDefaults.shared.value(for: \.suggestionFeatureEnabledProjectList)
            if !enabledList.contains(where: { path in projectRootURL.path.hasPrefix(path) }) {
                return false
            }
        }
        return true
    }

    private init(projectRootURL: URL) {
        self.projectRootURL = projectRootURL
        openedFileRecoverableStorage = .init(projectRootURL: projectRootURL)

        userDefaultsObserver.onChange = { [weak self] in
            guard let self else { return }
            _ = self.suggestionService
        }
        
        let openedFiles = openedFileRecoverableStorage.openedFiles
        for fileURL in openedFiles {
            _ = createFilespaceIfNeeded(fileURL: fileURL)
        }
    }

    func refreshUpdateTime() {
        lastSuggestionUpdateTime = Environment.now()
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

    /// This is the only way to create a workspace and a filespace.
    static func fetchOrCreateWorkspaceIfNeeded(fileURL: URL) async throws
        -> (workspace: Workspace, filespace: Filespace)
    {
        // If we know which project is opened.
        if let currentProjectURL = try await Environment.fetchCurrentProjectRootURLFromXcode() {
            if let existed = workspaces[currentProjectURL] {
                let filespace = existed.createFilespaceIfNeeded(fileURL: fileURL)
                return (existed, filespace)
            }
            
            let new = Workspace(projectRootURL: currentProjectURL)
            workspaces[currentProjectURL] = new
            let filespace = new.createFilespaceIfNeeded(fileURL: fileURL)
            return (new, filespace)
        }
        
        // If not, we try to reuse a filespace if found.
        //
        // Sometimes, we can't get the project root path from Xcode window, for example, when the
        // quick open window in displayed.
        for workspace in workspaces.values {
            if let filespace = workspace.filespaces[fileURL] {
                return (workspace, filespace)
            }
        }

        // If we can't find an existed one, we will try to guess it.
        // Most of the time we won't enter this branch, just incase.
        
        let workspaceURL = try await Environment.guessProjectRootURLForFile(fileURL)

        let workspace = {
            if let existed = workspaces[workspaceURL] {
                return existed
            }
            // Reuse existed workspace if possible
            for (_, workspace) in workspaces {
                if fileURL.path.hasPrefix(workspace.projectRootURL.path) {
                    return workspace
                }
            }
            return Workspace(projectRootURL: workspaceURL)
        }()

        let filespace = workspace.createFilespaceIfNeeded(fileURL: fileURL)
        workspaces[workspaceURL] = workspace
        workspace.refreshUpdateTime()
        return (workspace, filespace)
    }

    private func createFilespaceIfNeeded(fileURL: URL) -> Filespace {
        let existedFilespace = filespaces[fileURL]
        let filespace = existedFilespace ?? .init(fileURL: fileURL, onSave: { [weak self]
            filespace in
                guard let self else { return }
                notifySaveFile(filespace: filespace)
        })
        if filespaces[fileURL] == nil {
            filespaces[fileURL] = filespace
        }
        if existedFilespace == nil {
            notifyOpenFile(filespace: filespace)
        } else {
            filespace.refreshUpdateTime()
        }
        return filespace
    }
}

// MARK: - Suggestion

extension Workspace {
    @discardableResult
    func generateSuggestions(
        forFileAt fileURL: URL,
        editor: EditorContent
    ) async throws -> [CodeSuggestion] {
        refreshUpdateTime()

        let filespace = createFilespaceIfNeeded(fileURL: fileURL)

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

        guard let suggestionService else { throw SuggestionFeatureDisabledError() }
        let completions = try await suggestionService.getSuggestions(
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
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL],
              filespace.suggestions.count > 1
        else { return }
        filespace.suggestionIndex += 1
        if filespace.suggestionIndex >= filespace.suggestions.endIndex {
            filespace.suggestionIndex = 0
        }
    }

    func selectPreviousSuggestion(forFileAt fileURL: URL) {
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL],
              filespace.suggestions.count > 1
        else { return }
        filespace.suggestionIndex -= 1
        if filespace.suggestionIndex < 0 {
            filespace.suggestionIndex = filespace.suggestions.endIndex - 1
        }
    }

    func rejectSuggestion(forFileAt fileURL: URL, editor: EditorContent?) {
        refreshUpdateTime()

        if let editor, !editor.uti.isEmpty {
            filespaces[fileURL]?.uti = editor.uti
            filespaces[fileURL]?.tabSize = editor.tabSize
            filespaces[fileURL]?.indentSize = editor.indentSize
            filespaces[fileURL]?.usesTabsForIndentation = editor.usesTabsForIndentation
        }
        Task {
            await suggestionService?.notifyRejected(filespaces[fileURL]?.suggestions ?? [])
        }
        filespaces[fileURL]?.reset(resetSnapshot: false)
    }

    func acceptSuggestion(forFileAt fileURL: URL, editor: EditorContent?) -> CodeSuggestion? {
        refreshUpdateTime()
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
            await suggestionService?.notifyAccepted(suggestion)
            await suggestionService?.notifyRejected(allSuggestions)
        }

        filespaces[fileURL]?.reset()

        return suggestion
    }

    func notifyOpenFile(filespace: Filespace) {
        refreshUpdateTime()
        openedFileRecoverableStorage.openFile(fileURL: filespace.fileURL)
        Task {
            try await suggestionService?.notifyOpenTextDocument(
                fileURL: filespace.fileURL,
                content: try String(contentsOf: filespace.fileURL, encoding: .utf8)
            )
        }
    }

    func notifyUpdateFile(filespace: Filespace, content: String) {
        filespace.refreshUpdateTime()
        refreshUpdateTime()
        Task {
            try await suggestionService?.notifyChangeTextDocument(
                fileURL: filespace.fileURL,
                content: content
            )
        }
    }

    func notifySaveFile(filespace: Filespace) {
        filespace.refreshUpdateTime()
        refreshUpdateTime()
        Task {
            try await suggestionService?.notifySaveTextDocument(fileURL: filespace.fileURL)
        }
    }
}

// MARK: - Cleanup

extension Workspace {
    func cleanUp(availableTabs: Set<String>) {
        for (fileURL, _) in filespaces {
            if isFilespaceExpired(fileURL: fileURL, availableTabs: availableTabs) {
                Task {
                    try await suggestionService?.notifyCloseTextDocument(fileURL: fileURL)
                }
                openedFileRecoverableStorage.closeFile(fileURL: fileURL)
                filespaces[fileURL] = nil
            }
        }
    }

    func isFilespaceExpired(fileURL: URL, availableTabs: Set<String>) -> Bool {
        let filename = fileURL.lastPathComponent
        if availableTabs.contains(filename) { return false }
        guard let filespace = filespaces[fileURL] else { return true }
        return filespace.isExpired
    }

    func cancelInFlightRealtimeSuggestionRequests() async {
        guard let suggestionService else { return }
        await suggestionService.cancelRequest()
    }
}
