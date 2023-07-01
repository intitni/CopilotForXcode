import Foundation
import OpenAIService
import TokenEncoder

public struct OpenAIEmbedding: Embeddings {
    public var service: EmbeddingService
    public var shouldAverageLongEmbeddings: Bool
    /// Usually we won't hit the limit because the max token is 8191 and we will do text splitting
    /// before embedding.
    public var safe: Bool

    public init(
        configuration: EmbeddingConfiguration,
        shouldAverageLongEmbeddings: Bool = false,
        safe: Bool = false
    ) {
        service = EmbeddingService(configuration: configuration)
        self.shouldAverageLongEmbeddings = shouldAverageLongEmbeddings
        self.safe = safe
    }

    public func embed(documents: [Document]) async throws -> [EmbeddedDocument] {
        if safe {
            return try await getLenSafeEmbeddings(documents: documents)
        }
        return try await getEmbeddings(documents: documents)
    }

    public func embed(query: String) async throws -> [Float] {
        if safe {
            return try await getLenSafeEmbeddings(documents: [.init(
                pageContent: query,
                metadata: [:]
            )])
            .first?
            .embeddings ?? []
        }
        return try await getEmbeddings(documents: [.init(pageContent: query, metadata: [:])])
            .first?
            .embeddings ?? []
    }
}

extension OpenAIEmbedding {
    func getEmbeddings(
        documents: [Document]
    ) async throws -> [EmbeddedDocument] {
        try await withThrowingTaskGroup(
            of: (document: Document, embeddings: [Float]).self
        ) { group in
            for document in documents {
                group.addTask {
                    var retryCount = 6
                    var previousError: Error?
                    while retryCount > 0 {
                        do {
                            let embeddings = try await service.embed(text: document.pageContent)
                                .data
                                .map(\.embedding).first ?? []
                            return (document, embeddings)
                        } catch {
                            retryCount -= 1
                            previousError = error
                        }
                    }
                    throw previousError ?? CancellationError()
                }
            }
            var all = [EmbeddedDocument]()
            for try await result in group {
                all.append(.init(document: result.document, embeddings: result.embeddings))
            }
            return all
        }
    }

    /// OpenAI's embedding API doesn't support embedding inputs longer than the max token.
    /// https://github.com/openai/openai-cookbook/blob/main/examples/Embedding_long_inputs.ipynb
    func getLenSafeEmbeddings(
        documents: [Document]
    ) async throws -> [EmbeddedDocument] {
        struct Text {
            var document: Document
            var chunkedTokens: [[Int]]
        }

        var texts = documents.map { Text(document: $0, chunkedTokens: []) }
        let encoding = TiktokenCl100kBaseTokenEncoder()

        for (index, text) in texts.enumerated() {
            let token = encoding.encode(text: text.document.pageContent)
            // just incase the calculation is incorrect
            let maxToken = max(10, service.configuration.maxToken - 10)

            for j in stride(from: 0, to: token.count, by: maxToken) {
                texts[index].chunkedTokens.append(
                    Array(token[j..<min(j + maxToken, token.count)])
                )
            }
        }

        let batchedEmbeddings = try await withThrowingTaskGroup(
            of: (Document, [[Float]]).self
        ) { group in
            for text in texts {
                group.addTask {
                    var retryCount = 6
                    var previousError: Error?
                    guard !text.chunkedTokens.isEmpty
                    else { return (text.document, []) }
                    while retryCount > 0 {
                        do {
                            if text.chunkedTokens.count <= 1 {
                                // if possible, we should just let OpenAI do the tokenization.
                                return (
                                    text.document,
                                    try await service.embed(text: text.document.pageContent)
                                        .data
                                        .map(\.embedding)
                                )
                            }

                            if shouldAverageLongEmbeddings {
                                return (
                                    text.document,
                                    try await service.embed(tokens: text.chunkedTokens)
                                        .data
                                        .map(\.embedding)
                                )
                            }
                            // if `shouldAverageLongEmbeddings` is false,
                            // we only embed the first chunk to save some money.
                            return (
                                text.document,
                                try await service.embed(tokens: [text.chunkedTokens.first ?? []])
                                    .data
                                    .map(\.embedding)
                            )
                        } catch {
                            retryCount -= 1
                            previousError = error
                        }
                    }
                    throw previousError ?? CancellationError()
                }
            }
            var result = [(document: Document, embeddings: [[Float]])]()
            for try await response in group {
                try Task.checkCancellation()
                result.append((response.0, response.1))
            }
            return result
        }

        var results = [EmbeddedDocument]()

        for (document, embeddings) in batchedEmbeddings {
            if embeddings.count == 1, let first = embeddings.first {
                results.append(.init(document: document, embeddings: first))
            } else if embeddings.isEmpty {
                results.append(.init(document: document, embeddings: []))
            } else if shouldAverageLongEmbeddings {
                // unimplemented
                if let first = embeddings.first {
                    results.append(.init(document: document, embeddings: first))
                }
            } else if let first = embeddings.first {
                results.append(.init(document: document, embeddings: first))
            }
        }

        return results
    }
}

