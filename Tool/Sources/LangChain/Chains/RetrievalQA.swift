import Foundation

final class RetrievalQA: Chain {
    let vectorStore: VectorStore
    let embedding: Embeddings

    struct Output {
        var answer: String
        var sourceDocuments: [Document]
    }

    init(vectorStore: VectorStore, embedding: Embeddings) {
        self.vectorStore = vectorStore
        self.embedding = embedding
    }

    func callLogic(
        _ input: String,
        callbackManagers: [ChainCallbackManager]
    ) async throws -> Output {
        let embeddedQuestion = try awa
        
        return .init(answer: "", sourceDocuments: [])
    }

    func parseOutput(_ output: Output) -> String {
        return output.answer
    }
}

