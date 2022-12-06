import CopilotModel
import CopilotService
import Foundation
import SuggestionInjector

@ServiceActor
final class FileSuggestion {
    var fileURL: URL
    var index: Int
    var suggestions: [CopilotCompletion]

    init(fileURL: URL, suggestions: [CopilotCompletion]) {
        self.fileURL = fileURL
        self.suggestions = suggestions
        index = 0
    }
}

@ServiceActor
final class Workspace {
    let projectRootURL: URL
    var lastTriggerDate = Environment.now()
    var isExpired: Bool {
        Environment.now().timeIntervalSince(lastTriggerDate) > 60 * 60 * 24
    }

    var fileSuggestions = [URL: FileSuggestion]()

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
    ) async throws -> (content: String, cursorPosition: CursorPosition) {
        lastTriggerDate = Environment.now()
        let injector = SuggestionInjector()
        var lines = lines
        var cursorPosition = cursorPosition
        injector.rejectCurrentSuggestions(from: &lines, cursorPosition: &cursorPosition)
        let completions = try await service.getCompletions(
            fileURL: fileURL,
            content: lines.joined(separator: ""),
            cursorPosition: cursorPosition,
            tabSize: tabSize,
            indentSize: indentSize,
            usesTabsForIndentation: usesTabsForIndentation
        )
        if completions.isEmpty {
            return (content, cursorPosition)
        }
        fileSuggestions[fileURL] = .init(fileURL: fileURL, suggestions: completions)
        injector.proposeSuggestion(
            intoContentWithoutSuggestion: &lines,
            completion: completions[0],
            index: 0,
            count: completions.count
        )
        return (String(lines.joined(separator: "")), cursorPosition)
    }

    func getNextSuggestedCode(
        forFileAt fileURL: URL,
        content: String,
        lines: [String],
        cursorPosition: CursorPosition
    ) -> (content: String, cursorPosition: CursorPosition) {
        lastTriggerDate = Environment.now()
        guard let fileSuggestion = fileSuggestions[fileURL],
              fileSuggestion.suggestions.count > 1 else { return (content, cursorPosition) }
        var cursorPosition = cursorPosition
        fileSuggestion.index += 1
        if fileSuggestion.index >= fileSuggestion.suggestions.endIndex {
            fileSuggestion.index = 0
        }

        let suggestion = fileSuggestion.suggestions[fileSuggestion.index]
        let injector = SuggestionInjector()
        var lines = lines
        injector.rejectCurrentSuggestions(from: &lines, cursorPosition: &cursorPosition)
        injector.proposeSuggestion(
            intoContentWithoutSuggestion: &lines,
            completion: suggestion,
            index: fileSuggestion.index,
            count: fileSuggestion.suggestions.count
        )
        return (String(lines.joined(separator: "")), cursorPosition)
    }

    func getPreviousSuggestedCode(
        forFileAt fileURL: URL,
        content: String,
        lines: [String],
        cursorPosition: CursorPosition
    ) -> (content: String, cursorPosition: CursorPosition) {
        lastTriggerDate = Environment.now()
        guard let fileSuggestion = fileSuggestions[fileURL],
              fileSuggestion.suggestions.count > 1 else { return (content, cursorPosition) }
        var cursorPosition = cursorPosition
        fileSuggestion.index -= 1
        if fileSuggestion.index < 0 {
            fileSuggestion.index = fileSuggestion.suggestions.endIndex - 1
        }

        let suggestion = fileSuggestion.suggestions[fileSuggestion.index]
        let injector = SuggestionInjector()
        var lines = lines
        injector.rejectCurrentSuggestions(from: &lines, cursorPosition: &cursorPosition)
        injector.proposeSuggestion(
            intoContentWithoutSuggestion: &lines,
            completion: suggestion,
            index: fileSuggestion.index,
            count: fileSuggestion.suggestions.count
        )
        return (String(lines.joined(separator: "")), cursorPosition)
    }

    func getSuggestionAcceptedCode(
        forFileAt fileURL: URL,
        content: String,
        lines: [String],
        cursorPosition: CursorPosition
    ) -> (
        content: String,
        corsorPosition: CursorPosition?
    ) {
        lastTriggerDate = Environment.now()
        guard let fileSuggestion = fileSuggestions[fileURL],
              !fileSuggestion.suggestions.isEmpty,
              fileSuggestion.index >= 0,
              fileSuggestion.index < fileSuggestion.suggestions.endIndex
        else { return (content, nil) }
        
        var cursorPosition = cursorPosition

        var allSuggestions = fileSuggestion.suggestions
        let suggestion = allSuggestions.remove(at: fileSuggestion.index)
        let injector = SuggestionInjector()
        var lines = lines
        injector.rejectCurrentSuggestions(from: &lines, cursorPosition: &cursorPosition)
        injector.acceptSuggestion(
            intoContentWithoutSuggestion: &lines,
            cursorPosition: &cursorPosition,
            completion: suggestion
        )

        fileSuggestions[fileURL] = nil

        Task {
            await service.notifyAccepted(suggestion)
            await service.notifyRejected(allSuggestions)
        }

        return (String(lines.joined(separator: "")), cursorPosition)
    }

    func getSuggestionRejectedCode(
        forFileAt fileURL: URL,
        content _: String,
        lines: [String],
        cursorPosition: CursorPosition
    ) -> (content: String, cursorPosition: CursorPosition) {
        lastTriggerDate = Environment.now()
        let injector = SuggestionInjector()
        var lines = lines
        var cursorPosition = cursorPosition
        injector.rejectCurrentSuggestions(from: &lines, cursorPosition: &cursorPosition)

        Task {
            await service.notifyRejected(fileSuggestions[fileURL]?.suggestions ?? [])
        }

        fileSuggestions[fileURL] = nil
        return (String(lines.joined(separator: "")), cursorPosition)
    }
}
