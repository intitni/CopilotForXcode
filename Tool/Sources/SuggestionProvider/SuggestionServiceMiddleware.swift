import Foundation
import Logger
import SuggestionBasic

public protocol SuggestionServiceMiddleware {
    typealias Next = (SuggestionRequest) async -> AsyncThrowingStream<[CodeSuggestion], Error>

    func getSuggestion(
        _ request: SuggestionRequest,
        configuration: SuggestionServiceConfiguration,
        next: @escaping Next
    ) async -> AsyncThrowingStream<[CodeSuggestion], Error>
}

public enum SuggestionServiceMiddlewareContainer {
    static var frontMiddlewares: [SuggestionServiceMiddleware] = [
        PostProcessingSuggestionServiceMiddleware(),
    ]

    static var builtInMiddlewares: [SuggestionServiceMiddleware] = [
        DisabledLanguageSuggestionServiceMiddleware(),
        MockResultSuggestionServiceMiddleware(),
    ]

    static var leadingMiddlewares: [SuggestionServiceMiddleware] = []

    static var trailingMiddlewares: [SuggestionServiceMiddleware] = []

    public static var middlewares: [SuggestionServiceMiddleware] {
        frontMiddlewares + leadingMiddlewares + builtInMiddlewares + trailingMiddlewares
    }

    public static func addMiddleware(_ middleware: SuggestionServiceMiddleware) {
        trailingMiddlewares.append(middleware)
    }

    public static func addMiddlewares(_ middlewares: [SuggestionServiceMiddleware]) {
        trailingMiddlewares.append(contentsOf: middlewares)
    }

    public static func addLeadingMiddleware(_ middleware: SuggestionServiceMiddleware) {
        leadingMiddlewares.append(middleware)
    }

    public static func addLeadingMiddlewares(_ middlewares: [SuggestionServiceMiddleware]) {
        leadingMiddlewares.append(contentsOf: middlewares)
    }
}

public struct DisabledLanguageSuggestionServiceMiddleware: SuggestionServiceMiddleware {
    public init() {}

    struct DisabledLanguageError: Error, LocalizedError {
        let language: String
        var errorDescription: String? {
            "Suggestion service is disabled for \(language)."
        }
    }

    public func getSuggestion(
        _ request: SuggestionRequest,
        configuration: SuggestionServiceConfiguration,
        next: @escaping Next
    ) async -> AsyncThrowingStream<[CodeSuggestion], Error> {
        let language = languageIdentifierFromFileURL(request.fileURL)
        if UserDefaults.shared.value(for: \.suggestionFeatureDisabledLanguageList)
            .contains(where: { $0 == language.rawValue })
        {
            return .init {
                $0.finish(throwing: DisabledLanguageError(language: language.rawValue))
            }
        }

        return await next(request)
    }
}

public struct DebugSuggestionServiceMiddleware: SuggestionServiceMiddleware {
    public init() {}

    public func getSuggestion(
        _ request: SuggestionRequest,
        configuration: SuggestionServiceConfiguration,
        next: @escaping Next
    ) async -> AsyncThrowingStream<[CodeSuggestion], Error> {
        Logger.service.info("""
        Get suggestion for \(request.fileURL) at \(request.cursorPosition)
        """)

        return await next(request).handled(
            handleCodeSuggestions: { suggestions in
                Logger.service.info("""
                Receive \(suggestions.count) suggestions for \(request.fileURL) \
                at \(request.cursorPosition)
                """)
                return suggestions
            },
            handleError: { error in
                Logger.service.info("""
                Error: \(error.localizedDescription)
                """)
                return error
            }
        )
    }
}

public struct MockResultSuggestionServiceMiddleware: SuggestionServiceMiddleware {
    public init() {}
    
    let mock = false

    public func getSuggestion(
        _ request: SuggestionRequest,
        configuration: SuggestionServiceConfiguration,
        next: @escaping Next
    ) async -> AsyncThrowingStream<[CodeSuggestion], any Error> {
        #if DEBUG
        let stream = await next(request)
        if !mock {
            return stream
        }
        return .init { continuation in
            let task = Task {
                let lineNumber = request.cursorPosition.line
                let lineContent = request.lines[lineNumber]
                continuation.yield([
                    CodeSuggestion(
                        id: "mock-suggestion-1",
                        text: lineContent.replacingOccurrences(of: "\n", with: "!"),
                        position: CursorPosition(
                            line: lineNumber,
                            character: lineContent.utf16.count - 1
                        ),
                        range: CursorRange(
                            start: CursorPosition(line: lineNumber, character: 0),
                            end: CursorPosition(
                                line: lineNumber,
                                character: lineContent.utf16.count - 1
                            )
                        ),
                        effectiveRange: .replacingRange,
                        replacingLines: [lineContent],
                        descriptions: [],
                        middlewareComments: ["MockResultSuggestionServiceMiddleware"],
                        metadata: [.group: "Mock Suggestions"]
                    ),
                ])
                continuation.yield([
                    CodeSuggestion(
                        id: "mock-suggestion-2",
                        text: "",
                        position: .zero,
                        range: .zero,
                        effectiveRange: .full,
                        replacingLines: [],
                        descriptions: [.init(kind: .action, content: "mock")],
                        middlewareComments: ["MockResultSuggestionServiceMiddleware"],
                        metadata: [.group: "Mock Action"]
                    ),
                ])
                do {
                    for try await suggestions in stream {
                        continuation.yield(suggestions)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
        #else
        return await next(request)
        #endif
    }
}

public extension AsyncThrowingStream<[CodeSuggestion], Error> {
    func handled(
        handleCodeSuggestions: @escaping ([CodeSuggestion]) async -> [CodeSuggestion] = { $0 },
        handleError: @escaping (Error) -> Error = { $0 },
        onFinish: @escaping () -> Void = {}
    ) async -> AsyncThrowingStream<[CodeSuggestion], Error> {
        .init { continuation in
            let task = Task {
                do {
                    for try await suggestions in self {
                        await continuation.yield(handleCodeSuggestions(suggestions))
                    }
                    continuation.finish()
                    onFinish()
                } catch {
                    continuation.finish(throwing: handleError(error))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func suggestions(_ suggestions: [CodeSuggestion])
        -> AsyncThrowingStream<[CodeSuggestion], Error>
    {
        .init { continuation in
            continuation.yield(suggestions)
            continuation.finish()
        }
    }

    static func error(_ error: Error) -> AsyncThrowingStream<[CodeSuggestion], Error> {
        .init { continuation in
            continuation.finish(throwing: error)
        }
    }

    func allSuggestions() async throws -> [CodeSuggestion] {
        var all = [CodeSuggestion]()
        for try await codeSuggestions in self {
            all.append(contentsOf: codeSuggestions)
        }
        return all
    }
}

