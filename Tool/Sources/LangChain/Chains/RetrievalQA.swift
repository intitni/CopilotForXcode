import Foundation
import OpenAIService

public final class QAInformationRetrievalChain: Chain {
    let vectorStores: [VectorStore]
    let embedding: Embeddings
    let maxCount: Int

    public struct Output {
        public var information: String
        public var sourceDocuments: [Document]
    }

    public init(
        vectorStore: VectorStore,
        embedding: Embeddings,
        maxCount: Int = 5
    ) {
        vectorStores = [vectorStore]
        self.embedding = embedding
        self.maxCount = maxCount
    }

    public init(
        vectorStores: [VectorStore],
        embedding: Embeddings,
        maxCount: Int = 5
    ) {
        self.vectorStores = vectorStores
        self.embedding = embedding
        self.maxCount = maxCount
    }

    public func callLogic(
        _ input: String,
        callbackManagers: [CallbackManager]
    ) async throws -> Output {
        let embeddedQuestion = try await embedding.embed(query: input)
        let documentsSlice = await withTaskGroup(
            of: [(document: Document, distance: Float)].self
        ) { group in
            for vectorStore in vectorStores {
                group.addTask {
                    (try? await vectorStore.searchWithDistance(
                        embeddings: embeddedQuestion,
                        count: 5
                    ).filter { item in
                        item.distance < 0.31
                    }) ?? []
                }
            }
            var result = [(document: Document, distance: Float)]()
            for await items in group {
                result.append(contentsOf: items)
            }
            return result
        }.sorted { $0.distance < $1.distance }.prefix(maxCount)

        let documents = Array(documentsSlice)
        
        callbackManagers.send(CallbackEvents.RetrievalQADidExtractRelevantContent(info: documents))

        let relevantInformationChain = RelevantInformationExtractionChain()
        let relevantInformation = try await relevantInformationChain.run(
            .init(question: input, documents: documents),
            callbackManagers: callbackManagers
        )

        return .init(information: relevantInformation, sourceDocuments: documents.map(\.document))
    }

    public func parseOutput(_ output: Output) -> String {
        return output.information
    }
}

public extension CallbackEvents {
    struct RetrievalQADidExtractRelevantContent: CallbackEvent {
        public let info: [(document: Document, distance: Float)]
    }

    var retrievalQADidExtractRelevantContent: RetrievalQADidExtractRelevantContent.Type {
        RetrievalQADidExtractRelevantContent.self
    }
}

