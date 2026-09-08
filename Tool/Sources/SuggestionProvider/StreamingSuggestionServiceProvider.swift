import struct CopilotForXcodeKit.WorkspaceInfo
import Foundation
import SuggestionBasic

/// A provider that can hand out partial suggestions while the model is still generating.
///
/// Every element of the stream replaces the previous one: the text is cumulative and the ids are
/// stable for the whole round. The last element is the final result and equals what
/// ``SuggestionServiceProvider/getSuggestions(_:workspaceInfo:)`` would have returned.
public protocol StreamingSuggestionServiceProvider: SuggestionServiceProvider {
    func streamSuggestions(
        _ request: SuggestionRequest,
        workspaceInfo: WorkspaceInfo
    ) async -> AsyncThrowingStream<[CodeSuggestion], Error>
}

/// Helpers to build suggestion streams without repeating the task / continuation dance.
public enum SuggestionStreams {
    /// A stream that emits the result of one async operation and finishes.
    public static func single<Element>(
        _ operation: @escaping () async throws -> Element
    ) -> AsyncThrowingStream<Element, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    continuation.yield(try await operation())
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Forwards `upstream`, transforming every element. Dropping the consumer cancels `upstream`.
    public static func forward<Upstream: AsyncSequence, Element>(
        _ upstream: Upstream,
        mapError: @escaping (Error) -> Error = { $0 },
        transform: @escaping (Upstream.Element) async throws -> Element
    ) -> AsyncThrowingStream<Element, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await element in upstream {
                        try Task.checkCancellation()
                        continuation.yield(try await transform(element))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
