import Foundation
import OpenAIService

public final class RetrievalQAChain: Chain {
    let vectorStore: VectorStore
    let embedding: Embeddings

    public struct Output {
        public var answer: String
        public var sourceDocuments: [Document]
    }

    public init(
        vectorStore: VectorStore,
        embedding: Embeddings
    ) {
        self.vectorStore = vectorStore
        self.embedding = embedding
    }

    public func callLogic(
        _ input: String,
        callbackManagers: [CallbackManager]
    ) async throws -> Output {
        let embeddedQuestion = try await embedding.embed(query: input)
        let documents = try await vectorStore.searchWithDistance(
            embeddings: embeddedQuestion,
            count: 5
        )

        callbackManagers.send(CallbackEvents.RetrievalQADidExtractRelevantContent(info: documents))

        let relevantInformationChain = RelevantInformationExtractionChain()
        let relevantInformation = try await relevantInformationChain.run(
            .init(question: input, documents: documents),
            callbackManagers: callbackManagers
        )

        return .init(answer: relevantInformation, sourceDocuments: documents.map(\.document))
    }

    public func parseOutput(_ output: Output) -> String {
        return output.answer
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




