import Foundation
import ModificationBasic
import SuggestionBasic

public final class PreviewModificationAgent: ModificationAgent {
    public func send(_ request: Request) -> AsyncThrowingStream<Response, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let stream = try await modifyCode(
                        code: request.code,
                        requirement: request.requirement,
                        source: .init(
                            language: request.source.language,
                            documentURL: request.source.documentURL,
                            projectRootURL: request.source.projectRootURL,
                            content: request.source.content,
                            lines: request.source.lines,
                            range: request.range
                        ),
                        isDetached: request.isDetached,
                        extraSystemPrompt: request.extraSystemPrompt,
                        generateDescriptionRequirement: false
                    )

                    for try await (code, description) in stream {
                        continuation.yield(.code(code))
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public init() {}

    func modifyCode(
        code: String,
        requirement: String,
        source: PromptToCodeSource,
        isDetached: Bool,
        extraSystemPrompt: String?,
        generateDescriptionRequirement: Bool?
    ) async throws -> AsyncThrowingStream<(code: String, description: String), Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let code = """
                struct Cat {
                    var name: String
                }

                print("Hello world!")
                """
                let description = "I have created a struct `Cat`."
                var resultCode = ""
                var resultDescription = ""
                do {
                    for character in code {
                        try await Task.sleep(nanoseconds: 50_000_000)
                        resultCode.append(character)
                        continuation.yield((resultCode, resultDescription))
                    }
                    for character in description {
                        try await Task.sleep(nanoseconds: 50_000_000)
                        resultDescription.append(character)
                        continuation.yield((resultCode, resultDescription))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func stopResponding() {}
}

