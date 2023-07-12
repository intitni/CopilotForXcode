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
        public let info: RefineDocumentChain.IntermediateAnswer
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

    public struct IntermediateAnswer: Decodable {
        public var answer: String
        public var score: Double
        public var more: Bool

        public enum CodingKeys: String, CodingKey {
            case answer
            case score
            case more
        }

        init(answer: String, score: Double, more: Bool) {
            self.answer = answer
            self.score = score
            self.more = more
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            answer = try container.decode(String.self, forKey: .answer)
            score = (try? container.decode(Double.self, forKey: .score)) ?? 0
            more = (try? container.decode(Bool.self, forKey: .more)) ?? (score < 6)
        }
    }

    class FunctionProvider: ChatGPTFunctionProvider {
        var functionCallStrategy: FunctionCallStrategy? = .name("respond")
        var functions: [any ChatGPTFunction] = [RespondFunction()]
    }

    struct RespondFunction: ChatGPTFunction {
        typealias Arguments = IntermediateAnswer

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
                        .description: "The refined answer",
                    ],
                    "score": [
                        .type: "number",
                        .description: "The score of the answer, the higher the better. 0 to 10.",
                    ],
                    "more": [
                        .type: "boolean",
                        .description: "Whether more information is needed to complete the answer",
                    ],
                ],
                .required: ["answer", "score", "more"],
            ]
        }

        func prepare() async {}

        func call(arguments: Arguments) async throws -> Result {
            return Result()
        }
    }

    let initialChatModel: ChatModelChain<InitialInput>
    let refinementChatModel: ChatModelChain<RefinementInput>

    public init() {
        initialChatModel = .init(
            chatModel: OpenAIChat(
                configuration: UserPreferenceChatGPTConfiguration().overriding {
                    $0.temperature = 0
                    $0.runFunctionsAutomatically = false
                },
                memory: EmptyChatGPTMemory(),
                functionProvider: FunctionProvider(),
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
                configuration: UserPreferenceChatGPTConfiguration().overriding {
                    $0.temperature = 0
                    $0.runFunctionsAutomatically = false
                },
                memory: EmptyChatGPTMemory(),
                functionProvider: FunctionProvider(),
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

        func extractAnswer(_ chatMessage: ChatMessage) -> IntermediateAnswer {
            if let functionCall = chatMessage.functionCall {
                do {
                    let intermediateAnswer = try JSONDecoder().decode(
                        IntermediateAnswer.self,
                        from: functionCall.arguments.data(using: .utf8) ?? Data()
                    )
                    return intermediateAnswer
                } catch {
                    let intermediateAnswer = IntermediateAnswer(
                        answer: functionCall.arguments,
                        score: 0,
                        more: true
                    )
                    return intermediateAnswer
                }
            }
            return .init(answer: chatMessage.content ?? "", score: 0, more: true)
        }
        var output = try await initialChatModel.call(
            .init(
                question: input.question,
                document: firstDocument.document.pageContent,
                distance: firstDocument.distance
            ),
            callbackManagers: callbackManagers
        )
        var intermediateAnswer = extractAnswer(output)
        callbackManagers.send(
            CallbackEvents.RetrievalQADidGenerateIntermediateAnswer(info: intermediateAnswer)
        )

        for document in input.documents.dropFirst(1) where intermediateAnswer.more {
            output = try await refinementChatModel.call(
                .init(
                    question: input.question,
                    previousAnswer: intermediateAnswer.answer,
                    document: document.document.pageContent,
                    distance: document.distance
                ),
                callbackManagers: callbackManagers
            )
            intermediateAnswer = extractAnswer(output)
            callbackManagers.send(
                CallbackEvents.RetrievalQADidGenerateIntermediateAnswer(info: intermediateAnswer)
            )
        }
        return intermediateAnswer.answer
    }

    public func parseOutput(_ output: String) -> String {
        return output
    }
}

