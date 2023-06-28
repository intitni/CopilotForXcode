import Foundation
import OpenAIService
import PythonHelper
import PythonKit
import TokenEncoder

public struct OpenAIEmbedding: Embeddings {
    public var service: EmbeddingService
    /// Usually we won't hit the limit because the max token is 8191 and we will do text splitting
    /// before embedding.
    public var shouldAverageLongEmbeddings: Bool

    public init(configuration: EmbeddingConfiguration, shouldAverageLongEmbeddings: Bool = false) {
        service = EmbeddingService(configuration: configuration)
        self.shouldAverageLongEmbeddings = shouldAverageLongEmbeddings
    }

    public func embed(documents: [String]) async throws -> [[Float]] {
        []
    }

    public func embed(query: String) async throws -> [Float] {
        return try await getLenSafeEmbeddings(texts: [query]).first?.embeddings ?? []
    }
}

extension OpenAIEmbedding {
    func getLenSafeEmbeddings(
        texts: [String]
    ) async throws -> [(originalText: String, embeddings: [Float])] {
        struct Text {
            var rawText: String
            var chunkedTokens: [[Int]]
        }

        var texts = texts.map { Text(rawText: $0, chunkedTokens: []) }
        let encoding = TiktokenCl100kBaseTokenEncoder()

        for (index, text) in texts.enumerated() {
            let token = encoding.encode(text: text.rawText)
            // just incase the calculation is incorrect
            let maxToken = max(10, service.configuration.maxToken - 10)

            for j in stride(from: 0, to: token.count, by: maxToken) {
                texts[index].chunkedTokens.append(
                    Array(token[j..<min(j + maxToken, token.count)])
                )
            }
        }

        let batchedEmbeddings = try await withThrowingTaskGroup(
            of: (String, [[Float]]).self
        ) { group in
            for text in texts {
                group.addTask {
                    var retryCount = 6
                    var previousError: Error?
                    guard !text.chunkedTokens.isEmpty else { return (text.rawText, []) }
                    while retryCount > 0 {
                        do {
                            if text.chunkedTokens.count <= 1 {
                                // if possible, we should just let OpenAI do the tokenization.
                                return (
                                    text.rawText,
                                    try await service.embed(text: text.rawText)
                                        .data
                                        .map(\.embeddings)
                                )
                            }
                            if shouldAverageLongEmbeddings {
                                return (
                                    text.rawText,
                                    try await service.embed(tokens: text.chunkedTokens)
                                        .data
                                        .map(\.embeddings)
                                )
                            }
                            // if `shouldAverageLongEmbeddings` is false,
                            // we only embed the first chunk to save some money.
                            return (
                                text.rawText,
                                try await service.embed(tokens: [text.chunkedTokens.first ?? []])
                                    .data
                                    .map(\.embeddings)
                            )
                        } catch {
                            retryCount -= 1
                            previousError = error
                        }
                    }
                    throw previousError ?? CancellationError()
                }
            }
            var result = [(originalText: String, embeddings: [[Float]])]()
            for try await response in group {
                try Task.checkCancellation()
                result.append((response.0, response.1))
            }
            return result
        }

        var results = [(originalText: String, embeddings: [Float])]()

        for (text, embeddings) in batchedEmbeddings {
            if embeddings.count == 1, let first = embeddings.first {
                results.append((text, first))
            } else if embeddings.isEmpty {
                results.append((text, []))
            } else if shouldAverageLongEmbeddings {
                // untested
                do {
                    guard let averagedEmbeddings = try await runPython({
                        let numpy = try Python.attemptImportOnPythonThread("numpy")
                        let average = numpy.average(
                            embeddings,
                            axis: 0,
                            weights: embeddings.map(\.count)
                        )
                        let normalized = average / numpy.linalg.norm(embeddings)
                        return [Float](normalized.tolist())
                    }) else { throw CancellationError() }
                    results.append((text, averagedEmbeddings))
                } catch {
                    if let first = embeddings.first {
                        results.append((text, first))
                    }
                }
            } else if let first = embeddings.first {
                results.append((text, first))
            }
        }

        return results
    }
}

