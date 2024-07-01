import Foundation
import SuggestionBasic

public final class PreviewPromptToCodeService: PromptToCodeServiceType {
    public init() {}

    public func modifyCode(
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

