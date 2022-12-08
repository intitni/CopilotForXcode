import CopilotModel
import CopilotService
import Foundation
import SuggestionInjector
import XPCShared

@ServiceActor
final class Filespace {
    let fileURL: URL
    var suggestions: [CopilotCompletion] = [] {
        didSet { lastSuggestionUpdateTime = Environment.now() }
    }

    var suggestionIndex: Int = 0
    var latestContentHash: Int = 0
    var latestCursorPosition: CursorPosition = .init(line: -1, character: -1)
    var currentSuggestionLineRange: ClosedRange<Int>?

    private(set) var lastSuggestionUpdateTime: Date = Environment.now()
    var isExpired: Bool {
        Environment.now().timeIntervalSince(lastSuggestionUpdateTime) > 60 * 60 * 8
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func reset() {
        suggestions = []
        suggestionIndex = 0
        currentSuggestionLineRange = nil
    }
}

@ServiceActor
final class Workspace {
    let projectRootURL: URL
    var lastTriggerDate = Environment.now()
    var isExpired: Bool {
        Environment.now().timeIntervalSince(lastTriggerDate) > 60 * 60 * 8
    }

    var filespaces = [URL: Filespace]()

    private lazy var service: CopilotSuggestionServiceType = Environment
        .createSuggestionService(projectRootURL)

    init(projectRootURL: URL) {
        self.projectRootURL = projectRootURL
    }

    func getSuggestedCode(
        forFileAt fileURL: URL,
        content: String,
        lines: [String],
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool
    ) async throws -> UpdatedContent {
        lastTriggerDate = Environment.now()
        let injector = SuggestionInjector()
        var lines = lines
        var cursorPosition = cursorPosition

        let filespace = filespaces[fileURL] ?? .init(fileURL: fileURL)
        if filespaces[fileURL] == nil {
            filespaces[fileURL] = filespace
        }
        filespace.latestContentHash = content.hashValue
        filespace.latestCursorPosition = cursorPosition
        var extraInfo = SuggestionInjector.ExtraInfo()

        injector.rejectCurrentSuggestions(
            from: &lines,
            cursorPosition: &cursorPosition,
            extraInfo: &extraInfo
        )
        let completions = try await service.getCompletions(
            fileURL: fileURL,
            content: lines.joined(separator: ""),
            cursorPosition: cursorPosition,
            tabSize: tabSize,
            indentSize: indentSize,
            usesTabsForIndentation: usesTabsForIndentation
        )
        if completions.isEmpty {
            return .init(
                content: content,
                newCursor: cursorPosition,
                modifications: extraInfo.modifications
            )
        }

        filespace.suggestions = completions
        injector.proposeSuggestion(
            intoContentWithoutSuggestion: &lines,
            completion: completions[0],
            index: 0,
            count: completions.count,
            extraInfo: &extraInfo
        )
        return .init(
            content: String(lines.joined(separator: "")),
            newCursor: cursorPosition,
            modifications: extraInfo.modifications
        )
    }

    func getNextSuggestedCode(
        forFileAt fileURL: URL,
        content: String,
        lines: [String],
        cursorPosition: CursorPosition
    ) -> UpdatedContent {
        lastTriggerDate = Environment.now()
        guard let fileSuggestion = filespaces[fileURL],
              fileSuggestion.suggestions.count > 1
        else { return .init(content: content, modifications: []) }
        var cursorPosition = cursorPosition
        fileSuggestion.suggestionIndex += 1
        if fileSuggestion.suggestionIndex >= fileSuggestion.suggestions.endIndex {
            fileSuggestion.suggestionIndex = 0
        }

        let suggestion = fileSuggestion.suggestions[fileSuggestion.suggestionIndex]
        let injector = SuggestionInjector()
        var extraInfo = SuggestionInjector.ExtraInfo()
        var lines = lines
        injector.rejectCurrentSuggestions(
            from: &lines,
            cursorPosition: &cursorPosition,
            extraInfo: &extraInfo
        )
        injector.proposeSuggestion(
            intoContentWithoutSuggestion: &lines,
            completion: suggestion,
            index: fileSuggestion.suggestionIndex,
            count: fileSuggestion.suggestions.count,
            extraInfo: &extraInfo
        )
        return .init(
            content: String(lines.joined(separator: "")),
            newCursor: cursorPosition,
            modifications: extraInfo.modifications
        )
    }

    func getPreviousSuggestedCode(
        forFileAt fileURL: URL,
        content: String,
        lines: [String],
        cursorPosition: CursorPosition
    ) -> UpdatedContent {
        lastTriggerDate = Environment.now()
        guard let fileSuggestion = filespaces[fileURL],
              fileSuggestion.suggestions.count > 1
        else { return .init(content: content, modifications: []) }
        var cursorPosition = cursorPosition
        fileSuggestion.suggestionIndex -= 1
        if fileSuggestion.suggestionIndex < 0 {
            fileSuggestion.suggestionIndex = fileSuggestion.suggestions.endIndex - 1
        }
        var extraInfo = SuggestionInjector.ExtraInfo()
        let suggestion = fileSuggestion.suggestions[fileSuggestion.suggestionIndex]
        let injector = SuggestionInjector()
        var lines = lines
        injector.rejectCurrentSuggestions(
            from: &lines,
            cursorPosition: &cursorPosition,
            extraInfo: &extraInfo
        )
        injector.proposeSuggestion(
            intoContentWithoutSuggestion: &lines,
            completion: suggestion,
            index: fileSuggestion.suggestionIndex,
            count: fileSuggestion.suggestions.count,
            extraInfo: &extraInfo
        )
        return .init(
            content: String(lines.joined(separator: "")),
            newCursor: cursorPosition,
            modifications: extraInfo.modifications
        )
    }

    func getSuggestionAcceptedCode(
        forFileAt fileURL: URL,
        content: String,
        lines: [String],
        cursorPosition: CursorPosition
    ) -> UpdatedContent {
        lastTriggerDate = Environment.now()
        guard let fileSuggestion = filespaces[fileURL],
              !fileSuggestion.suggestions.isEmpty,
              fileSuggestion.suggestionIndex >= 0,
              fileSuggestion.suggestionIndex < fileSuggestion.suggestions.endIndex
        else { return .init(content: content, modifications: []) }

        var cursorPosition = cursorPosition
        var extraInfo = SuggestionInjector.ExtraInfo()
        var allSuggestions = fileSuggestion.suggestions
        let suggestion = allSuggestions.remove(at: fileSuggestion.suggestionIndex)
        let injector = SuggestionInjector()
        var lines = lines
        injector.rejectCurrentSuggestions(
            from: &lines,
            cursorPosition: &cursorPosition,
            extraInfo: &extraInfo
        )
        injector.acceptSuggestion(
            intoContentWithoutSuggestion: &lines,
            cursorPosition: &cursorPosition,
            completion: suggestion,
            extraInfo: &extraInfo
        )

        Task {
            await service.notifyAccepted(suggestion)
            await service.notifyRejected(allSuggestions)
        }

        filespaces[fileURL]?.reset()
        return .init(
            content: String(lines.joined(separator: "")),
            newCursor: cursorPosition,
            modifications: extraInfo.modifications
        )
    }

    func getSuggestionRejectedCode(
        forFileAt fileURL: URL,
        content _: String,
        lines: [String],
        cursorPosition: CursorPosition
    ) -> UpdatedContent {
        lastTriggerDate = Environment.now()
        let injector = SuggestionInjector()
        var lines = lines
        var cursorPosition = cursorPosition
        var extraInfo = SuggestionInjector.ExtraInfo()
        injector.rejectCurrentSuggestions(
            from: &lines,
            cursorPosition: &cursorPosition,
            extraInfo: &extraInfo
        )

        Task {
            await service.notifyRejected(filespaces[fileURL]?.suggestions ?? [])
        }

        filespaces[fileURL]?.reset()
        return .init(
            content: String(lines.joined(separator: "")),
            newCursor: cursorPosition,
            modifications: extraInfo.modifications
        )
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
}
