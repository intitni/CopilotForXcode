import CopilotModel
import CopilotService
import Environment
import Foundation
import SuggestionInjector
import XPCShared

@ServiceActor
final class Filespace {
    struct Snapshot: Equatable {
        var linesHash: Int
        var cursorPosition: CursorPosition
    }

    let fileURL: URL
    var suggestions: [CopilotCompletion] = [] {
        didSet { lastSuggestionUpdateTime = Environment.now() }
    }

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
    let projectRootURL: URL
    var lastTriggerDate = Environment.now()
    var isExpired: Bool {
        Environment.now().timeIntervalSince(lastTriggerDate) > 60 * 60 * 8
    }

    private(set) var filespaces = [URL: Filespace]()
    var isRealtimeSuggestionEnabled: Bool {
        UserDefaults.shared.bool(forKey: SettingsKey.realtimeSuggestionToggle)
    }

    var realtimeSuggestionRequests = Set<Task<Void, Error>>()

    private lazy var service: CopilotSuggestionServiceType = Environment
        .createSuggestionService(projectRootURL)

    init(projectRootURL: URL) {
        self.projectRootURL = projectRootURL
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

    static func fetchOrCreateWorkspaceIfNeeded(fileURL: URL) async throws -> (workspace: Workspace, filespace: Filespace) {
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
        content: String,
        lines: [String],
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
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

        let snapshot = Filespace.Snapshot(
            linesHash: lines.hashValue,
            cursorPosition: cursorPosition
        )

        filespace.suggestionSourceSnapshot = snapshot

        let completions = try await service.getCompletions(
            fileURL: fileURL,
            content: lines.joined(separator: ""),
            cursorPosition: cursorPosition,
            tabSize: tabSize,
            indentSize: indentSize,
            usesTabsForIndentation: usesTabsForIndentation,
            ignoreSpaceOnlySuggestions: true
        )

        filespace.suggestions = completions
        
        return completions
    }

    func selectNextSuggestion(
        forFileAt fileURL: URL,
        content _: String,
        lines: [String]
    ) {
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

    func selectPreviousSuggestion(
        forFileAt fileURL: URL,
        content _: String,
        lines: [String]
    ) {
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

    func rejectSuggestion(forFileAt fileURL: URL) {
        cancelInFlightRealtimeSuggestionRequests()
        lastTriggerDate = Environment.now()
        Task {
            await service.notifyRejected(filespaces[fileURL]?.suggestions ?? [])
        }
        filespaces[fileURL]?.reset(resetSnapshot: false)
    }

    func acceptSuggestion(forFileAt fileURL: URL) -> CopilotCompletion? {
        cancelInFlightRealtimeSuggestionRequests()
        lastTriggerDate = Environment.now()
        guard let filespace = filespaces[fileURL],
              !filespace.suggestions.isEmpty,
              filespace.suggestionIndex >= 0,
              filespace.suggestionIndex < filespace.suggestions.endIndex
        else { return nil }

        var allSuggestions = filespace.suggestions
        let suggestion = allSuggestions.remove(at: filespace.suggestionIndex)

        Task {
            await service.notifyAccepted(suggestion)
            await service.notifyRejected(allSuggestions)
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
