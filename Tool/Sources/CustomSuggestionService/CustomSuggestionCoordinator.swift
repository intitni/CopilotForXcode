import CopilotForXcodeKit
import enum CopilotForXcodeKit.SuggestionServiceError
import Foundation
import Preferences
import AIModel

actor CustomSuggestionCoordinator {
    enum Model {
        case chatModel(ChatModel)
        case completionModel(CompletionModel)
        case tabbyModel(TabbyModel)
        case fimModel(FIMModel)
    }

    enum SelectionError: Swift.Error, LocalizedError {
        case modelMissing(String)

        var errorDescription: String? {
            switch self {
            case let .modelMissing(id):
                if id.isEmpty {
                    return "No suggestion model is selected. Pick one in Service › Custom Model."
                }
                return "Selected suggestion model \"\(id)\" no longer exists. Pick one in Service › Custom Model."
            }
        }
    }

    var onGoingTask: Task<[CodeSuggestion], Error>?
    var lastNoticeDate: Date?

    func cancelRequest() {
        onGoingTask?.cancel()
        onGoingTask = nil
    }

    func getSuggestions(
        _ request: SuggestionRequest,
        workspace: WorkspaceInfo
    ) async throws -> [CodeSuggestion] {
        onGoingTask?.cancel()
        onGoingTask = nil
        let task = Task {
            try await CodeCompletionLogger.$logger.withValue(.init(request: request)) {
                do {
                    let lines = request.content.breakLines()
                    let (previousLines, nextLines) = Self.split(
                        code: request.content,
                        lines: lines,
                        at: request.cursorPosition
                    )
                    let strategy = getStrategy(
                        sourceRequest: request,
                        prefix: previousLines,
                        suffix: nextLines
                    )

                    if strategy.shouldSkip {
                        return [CodeSuggestion]()
                    }

                    let service = CodeCompletionService()
                    let model = try getModel()
                    let prompt = strategy.createPrompt()
                    let postProcessor = strategy.createRawSuggestionPostProcessor()
                    let stopStream = strategy.createStreamStopStrategy(model: model)

                    let suggestedCodeSnippets: [String]

                    switch model {
                    case let .chatModel(model):
                        CodeCompletionLogger.logger.logModel(model)
                        suggestedCodeSnippets = try await service.getCompletions(
                            prompt,
                            streamStopStrategy: stopStream,
                            model: model,
                            count: 1
                        )
                    case let .completionModel(model):
                        CodeCompletionLogger.logger.logModel(model)
                        suggestedCodeSnippets = try await service.getCompletions(
                            prompt,
                            streamStopStrategy: stopStream,
                            model: model,
                            count: 1
                        )
                    case let .tabbyModel(model):
                        CodeCompletionLogger.logger.logModel(model)
                        suggestedCodeSnippets = try await service.getCompletions(
                            prompt,
                            streamStopStrategy: stopStream,
                            model: model,
                            count: 1
                        )
                    case let .fimModel(model):
                        CodeCompletionLogger.logger.logModel(model)
                        suggestedCodeSnippets = try await service.getCompletions(
                            prompt,
                            streamStopStrategy: stopStream,
                            model: model,
                            count: 1
                        )
                    }

                    CodeCompletionLogger.logger.finish()

                    return suggestedCodeSnippets
                        .filter { !$0.allSatisfy { $0.isWhitespace || $0.isNewline } }
                        .map {
                            let suggestionText = postProcessor
                                .postProcess(
                                    rawSuggestion: $0,
                                    infillPrefix: prompt.suggestionPrefix.prependingValue,
                                    suffix: prompt.suffix
                                )
                                .keepLines(
                                    count: UserDefaults.shared
                                        .value(for: \.customSuggestionMaxLines)
                                )
                                .removeTrailingNewlinesAndWhitespace()

                            return CodeSuggestion(
                                id: UUID().uuidString,
                                text: suggestionText,
                                position: request.cursorPosition,
                                range: .init(
                                    start: .init(
                                        line: request.cursorPosition.line,
                                        character: 0
                                    ),
                                    end: request.cursorPosition
                                )
                            )
                        }
                } catch {
                    CodeCompletionLogger.logger.error(error)
                    throw mapUserFacingError(error)
                }
            }
        }
        onGoingTask = task
        return try await task.value
    }

    func getModel() throws -> Model {
        let id = UserDefaults.shared.value(for: \.customSuggestionModelId)
        let models = UserDefaults.shared.value(for: \.chatModels)
        if let existedModel = models.first(where: { $0.id == id }) {
            return .chatModel(existedModel)
        }
        guard let type = CustomModelType(rawValue: id) else {
            throw SelectionError.modelMissing(id)
        }
        switch type {
        case .completionModel:
            return .completionModel(UserDefaults.shared.value(for: \.customSuggestionCompletionModel))
        case .tabby:
            return .tabbyModel(UserDefaults.shared.value(for: \.customSuggestionTabbyModel))
        case .fimModel:
            return .fimModel(UserDefaults.shared.value(for: \.customSuggestionFIMModel))
        }
    }

    func mapUserFacingError(_ error: Swift.Error) -> Swift.Error {
        if error is CancellationError { return error }
        if let urlError = error as? URLError, urlError.code == .cancelled { return error }
        if error is SuggestionServiceError { return error }
        let now = Date()
        if let lastNoticeDate, now.timeIntervalSince(lastNoticeDate) < 30 {
            return SuggestionServiceError.silent(error)
        }
        lastNoticeDate = now
        return SuggestionServiceError.notice(error)
    }

    func getStrategy(
        sourceRequest: SuggestionRequest,
        prefix: [String],
        suffix: [String]
    ) -> any RequestStrategy {
        let id = UserDefaults.shared.value(for: \.customSuggestionRequestStrategyId)
        let type = CustomModelType(rawValue: UserDefaults.shared.value(for: \.customSuggestionModelId))
        if let type, type == .tabby {
            return TabbyRequestStrategy(
                sourceRequest: sourceRequest,
                prefix: prefix,
                suffix: suffix
            )
        }
        if let type, type == .fimModel {
            return FIMEndpointRequestStrategy(
                sourceRequest: sourceRequest,
                prefix: prefix,
                suffix: suffix
            )
        }
        let strategyOption = RequestStrategyOption(rawValue: id) ?? .default
        return strategyOption.strategy.init(
            sourceRequest: sourceRequest,
            prefix: prefix,
            suffix: suffix
        )
    }

    static func split(
        code: String,
        lines: [String],
        at cursorPosition: CursorPosition
    ) -> (head: [String], tail: [String]) {
        if code.isEmpty { return ([], []) }
        if lines.isEmpty { return ([], []) }
        if cursorPosition.line < 0 { return ([], lines) }
        if cursorPosition.line >= lines.endIndex { return (lines, []) }

        let (previousLines, nextLines): ([String], [String]) = {
            let previousLines = Array(lines[0..<cursorPosition.line])
            let nextLines = cursorPosition.line + 1 >= lines.endIndex
                ? []
                : Array(lines[(cursorPosition.line + 1)...])
            let splitLine = lines[cursorPosition.line]
            if cursorPosition.character < 0 {
                return (previousLines, [splitLine] + nextLines)
            }
            if cursorPosition.character >= splitLine.count {
                return (previousLines + [splitLine], nextLines)
            }
            let firstHalf = String(splitLine[..<splitLine.index(
                splitLine.startIndex,
                offsetBy: cursorPosition.character
            )])
            let secondHalf = String(splitLine[splitLine.index(
                splitLine.startIndex,
                offsetBy: cursorPosition.character
            )...])
            return (previousLines + [firstHalf], [secondHalf] + nextLines)
        }()

        return (previousLines, nextLines)
    }
}

extension String {
    func keepLines(count: Int) -> String {
        if count <= 0 { return self }
        let lines = breakLines()
        return lines.prefix(count).joined()
    }

    func removeTrailingNewlinesAndWhitespace() -> String {
        var text = self[...]
        while let last = text.last, last.isNewline || last.isWhitespace {
            text = text.dropLast(1)
        }
        return String(text)
    }
}

