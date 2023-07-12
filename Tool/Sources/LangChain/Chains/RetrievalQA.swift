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
        let refinementChain = RefineDocumentChain()
        let answer = try await refinementChain.run(
            .init(question: input, documents: documents),
            callbackManagers: callbackManagers
        )

        return .init(answer: answer, sourceDocuments: documents.map(\.document))
    }

    public func parseOutput(_ output: Output) -> String {
        return output.answer
    }
}

public extension CallbackEvents {
    struct RetrievalQADidGenerateIntermediateAnswer: CallbackEvent {
        public let info: String
    }
}

public final class RefineDocumentChain: Chain {
    public struct Input {
        var question: String
        var documents: [(document: Document, distance: Float)]
    }

    struct InitialInput {
        var question: String
        var document: String
        var distance: Float
    }

    struct RefinementInput {
        var question: String
        var previousAnswer: String
        var document: String
        var distance: Float
    }

    class FunctionProvider: ChatGPTFunctionProvider {
        var functions: [any ChatGPTFunction] = []
    }

    struct RespondFunction: ChatGPTFunction {
        struct Arguments: Codable {
            var answer: String
            var score: Double
            var more: Bool
        }

        struct Result: ChatGPTFunctionResult {
            var botReadableContent: String { "" }
        }

        var reportProgress: (String) async -> Void = { _ in }

        var name: String = "respond"
        var description: String = "Respond with the refined answer"
        var argumentSchema: JSONSchemaValue {
            return [
                .type: "object",
                .properties: [
                    "answer": [
                        .type: "string",
                        .description: "The answer",
                    ],
                    "score": [
                        .type: "number",
                        .description: "The score of the answer, the higher the better",
                    ],
                    "more": [
                        .type: "boolean",
                        .description: "Whether more information is needed to complete the answer",
                    ],
                ],
            ]
        }

        func prepare() async {}

        func call(arguments: Arguments) async throws -> Result {
            return Result()
        }
    }

    let initialChatModel: ChatModelChain<InitialInput>
    let refinementChatModel: ChatModelChain<RefinementInput>
    let initialChatMemory: ChatGPTMemory
    let refinementChatMemory: ChatGPTMemory

    public init() {
        initialChatMemory = ConversationChatGPTMemory(systemPrompt: "")
        refinementChatMemory = ConversationChatGPTMemory(systemPrompt: "")

        initialChatModel = .init(
            chatModel: OpenAIChat(
                configuration: UserPreferenceChatGPTConfiguration()
                    .overriding(.init(temperature: 0)),
                memory: initialChatMemory,
                stream: false
            ),
            promptTemplate: { input in [
                .init(role: .system, content: """
                The user will send you a question, you must answer it at your best.
                You can use the following document as a reference:###
                \(input.document)
                ###
                """),
                .init(role: .user, content: input.question),
            ] }
        )
        refinementChatModel = .init(
            chatModel: OpenAIChat(
                configuration: UserPreferenceChatGPTConfiguration()
                    .overriding(.init(temperature: 0)),
                memory: refinementChatMemory,
                stream: false
            ),
            promptTemplate: { input in [
                .init(role: .system, content: """
                The user will send you a question, you must refine your previous answer to it at your best.
                You should focus on answering the question, there is no need to add extra details in other topics.
                Previous answer:###
                \(input.previousAnswer)
                ###
                You can use the following document as a reference:###
                \(input.document)
                ###
                """),
                .init(role: .user, content: input.question),
            ] }
        )
    }

    public func callLogic(
        _ input: Input,
        callbackManagers: [CallbackManager]
    ) async throws -> String {
        guard let firstDocument = input.documents.first else {
            return ""
        }
        var output = try await initialChatModel.call(
            .init(
                question: input.question,
                document: firstDocument.document.pageContent,
                distance: firstDocument.distance
            ),
            callbackManagers: callbackManagers
        )
        guard var content = output.content else { return "" }
        callbackManagers
            .send(CallbackEvents.RetrievalQADidGenerateIntermediateAnswer(info: content))
        for document in input.documents.dropFirst(1) {
            output = try await refinementChatModel.call(
                .init(
                    question: input.question,
                    previousAnswer: output,
                    document: document.document.pageContent,
                    distance: document.distance
                ),
                callbackManagers: callbackManagers
            )
            callbackManagers
                .send(CallbackEvents.RetrievalQADidGenerateIntermediateAnswer(info: output))
        }
        return output
    }

    public func parseOutput(_ output: String) -> String {
        return output
    }
}

