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

    /// Everything a completion round derives from the request and the preferences.
    struct Round {
        let request: SuggestionRequest
        let prompt: PromptStrategy
        let postProcessor: RawSuggestionPostProcessingStrategy
        let stopStream: StreamStopStrategy
        let model: Model
        let maxLines: Int

        /// Turns raw model output into the suggestion shown to the user; nil when it is blank.
        func makeSuggestion(from rawSuggestion: String, id: String) -> CodeSuggestion? {
            if rawSuggestion.allSatisfy({ $0.isWhitespace || $0.isNewline }) { return nil }
            let suggestionText = postProcessor
                .postProcess(
                    rawSuggestion: rawSuggestion,
                    infillPrefix: prompt.suggestionPrefix.prependingValue,
                    suffix: prompt.suffix
                )
                .keepLines(count: maxLines)
                .removeTrailingNewlinesAndWhitespace()

            return CodeSuggestion(
                id: id,
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
    }

    /// Minimum interval between two partial emissions while streaming.
    static let partialEmitInterval: TimeInterval = 0.05

    /// Cancels the in-flight round, whichever entry point started it.
    private var cancelOnGoingRound: (() -> Void)?
    var lastNoticeDate: Date?

    func cancelRequest() {
        cancelOnGoingRound?()
        cancelOnGoingRound = nil
    }

    func getSuggestions(
        _ request: SuggestionRequest,
        workspace: WorkspaceInfo
    ) async throws -> [CodeSuggestion] {
        cancelRequest()
        let snapshot = Self.currentSnapshot()
        let task = Task {
            try await CodeCompletionLogger.$logger.withValue(.init(request: request)) {
                do {
                    guard let round = try prepareRound(request, snapshot: snapshot) else {
                        return [CodeSuggestion]()
                    }

                    let suggestedCodeSnippets = try await CodeCompletionService().getCompletions(
                        round.prompt,
                        streamStopStrategy: round.stopStream,
                        model: round.model,
                        count: 1
                    )

                    CodeCompletionLogger.logger.finish()

                    return suggestedCodeSnippets.compactMap {
                        round.makeSuggestion(from: $0, id: UUID().uuidString)
                    }
                } catch {
                    CodeCompletionLogger.logger.error(error)
                    throw mapUserFacingError(error)
                }
            }
        }
        cancelOnGoingRound = { task.cancel() }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    /// Streams the round: partial suggestions (same id, growing text) at most every
    /// ``partialEmitInterval``, then the final one. Blank partials are skipped.
    func streamSuggestions(
        _ request: SuggestionRequest,
        workspace: WorkspaceInfo
    ) -> AsyncThrowingStream<[CodeSuggestion], Swift.Error> {
        cancelRequest()
        let snapshot = Self.currentSnapshot()
        return AsyncThrowingStream { continuation in
            let task = Task {
                await CodeCompletionLogger.$logger.withValue(.init(request: request)) {
                    do {
                        guard let round = try prepareRound(request, snapshot: snapshot) else {
                            continuation.finish()
                            return
                        }
                        let id = UUID().uuidString
                        let completion = try await CodeCompletionService().streamCompletion(
                            round.prompt,
                            streamStopStrategy: round.stopStream,
                            model: round.model
                        )

                        var latest: String?
                        var lastEmit = Date.distantPast
                        for try await partial in completion {
                            try Task.checkCancellation()
                            latest = partial
                            let now = Date()
                            guard now.timeIntervalSince(lastEmit) >= Self.partialEmitInterval,
                                  let suggestion = round.makeSuggestion(from: partial, id: id)
                            else { continue }
                            lastEmit = now
                            continuation.yield([suggestion])
                            CodeCompletionLogger.logger.logPartial()
                        }
                        try Task.checkCancellation()

                        if let latest { CodeCompletionLogger.logger.logResponse(latest) }
                        CodeCompletionLogger.logger.finish()

                        let final = latest.flatMap { round.makeSuggestion(from: $0, id: id) }
                        continuation.yield(final.map { [$0] } ?? [])
                        continuation.finish()
                    } catch {
                        CodeCompletionLogger.logger.error(error)
                        continuation.finish(throwing: mapUserFacingError(error))
                    }
                }
            }
            cancelOnGoingRound = { task.cancel() }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    struct PreferenceSnapshot {
        var modelId: String
        var chatModels: [ChatModel]
        var strategyId: String
    }

    static func currentSnapshot() -> PreferenceSnapshot {
        PreferenceSnapshot(
            modelId: UserDefaults.shared.value(for: \.customSuggestionModelId),
            chatModels: UserDefaults.shared.value(for: \.chatModels),
            strategyId: UserDefaults.shared.value(for: \.customSuggestionRequestStrategyId)
        )
    }

    /// Nil when the strategy decides there is nothing to complete here.
    func prepareRound(_ request: SuggestionRequest, snapshot: PreferenceSnapshot) throws -> Round? {
        let lines = request.content.breakLines()
        let (previousLines, nextLines) = Self.split(
            code: request.content,
            lines: lines,
            at: request.cursorPosition
        )
        let strategy = getStrategy(
            sourceRequest: request,
            prefix: previousLines,
            suffix: nextLines,
            snapshot: snapshot
        )

        if strategy.shouldSkip { return nil }

        let model = try getModel(snapshot)
        logModel(model)

        return Round(
            request: request,
            prompt: strategy.createPrompt(),
            postProcessor: strategy.createRawSuggestionPostProcessor(),
            stopStream: strategy.createStreamStopStrategy(model: model),
            model: model,
            maxLines: UserDefaults.shared.value(for: \.customSuggestionMaxLines)
        )
    }

    func logModel(_ model: Model) {
        switch model {
        case let .chatModel(model):
            CodeCompletionLogger.logger.logModel(model)
        case let .completionModel(model):
            CodeCompletionLogger.logger.logModel(model)
        case let .tabbyModel(model):
            CodeCompletionLogger.logger.logModel(model)
        case let .fimModel(model):
            CodeCompletionLogger.logger.logModel(model)
        }
    }

    func getModel(_ snapshot: PreferenceSnapshot) throws -> Model {
        let id = snapshot.modelId
        let models = snapshot.chatModels
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
        suffix: [String],
        snapshot: PreferenceSnapshot
    ) -> any RequestStrategy {
        let id = snapshot.strategyId
        let type = CustomModelType(rawValue: snapshot.modelId)
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
