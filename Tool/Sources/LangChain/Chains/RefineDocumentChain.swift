import ChatBasic
import Foundation
import OpenAIService
import Preferences

public final class RefineDocumentChain: Chain {
    public struct Input {
        var question: String
        var documents: [(document: Document, distance: Float)]
    }

    struct RefinementInput {
        var index: Int
        var totalCount: Int
        var question: String
        var previousAnswer: String?
        var document: String
        var distance: Float
    }

    public struct IntermediateAnswer: Decodable {
        public var answer: String
        public var usefulness: Double
        public var more: Bool

        public enum CodingKeys: String, CodingKey {
            case answer
            case usefulness
            case more
        }

        init(answer: String, usefulness: Double, more: Bool) {
            self.answer = answer
            self.usefulness = usefulness
            self.more = more
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            answer = try container.decode(String.self, forKey: .answer)
            usefulness = (try? container.decode(Double.self, forKey: .usefulness)) ?? 0
            more = (try? container.decode(Bool.self, forKey: .more)) ?? true
        }
    }

    class FunctionProvider: ChatGPTFunctionProvider {
        var functionCallStrategy: FunctionCallStrategy? = .function(name: "respond")
        var functions: [any ChatGPTFunction] = [RespondFunction()]
    }

    struct RespondFunction: ChatGPTArgumentsCollectingFunction {
        typealias Arguments = IntermediateAnswer
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
                    "usefulness": [
                        .type: "number",
                        .description: "How useful the page of document is in generating the answer, the higher the better. 0 to 10",
                    ],
                    "more": [
                        .type: "boolean",
                        .description: "Whether you want to read the next page. The next page maybe less relevant to the question",
                    ],
                ],
                .required: ["answer", "more", "usefulness"],
            ]
        }
    }

    func buildChatModel() -> ChatModelChain<RefinementInput> {
        .init(
            chatModel: OpenAIChat(
                configuration: UserPreferenceChatGPTConfiguration(
                    chatModelKey: \.preferredChatModelIdForUtilities
                )
                .overriding {
                    $0.temperature = 0
                    $0.runFunctionsAutomatically = false
                },
                memory: EmptyChatGPTMemory(),
                functionProvider: FunctionProvider(),
                stream: false
            ),
            promptTemplate: { input in [
                .init(
                    role: .system,
                    content: {
                        if let previousAnswer = input.previousAnswer {
                            return """
                            I will send you a question about a document, you must refine your previous answer to it only according to the document.
                            Previous answer:###
                            \(previousAnswer)
                            ###
                            Page \(input.index) of \(input.totalCount) of the document:###
                            \(input.document)
                            ###
                            """
                        } else {
                            return """
                            I will send you a question about a document, you must answer it only according to the document.
                            Page \(input.index) of \(input.totalCount) of the document:###
                            \(input.document)
                            ###
                            """
                        }
                    }()

                ),
                .init(role: .user, content: input.question),
            ] }
        )
    }

    public init() {}

    public func callLogic(
        _ input: Input,
        callbackManagers: [CallbackManager]
    ) async throws -> String {
        var intermediateAnswer: IntermediateAnswer?

        for (index, document) in input.documents.enumerated() {
            if let intermediateAnswer, !intermediateAnswer.more { break }

            let output = try await buildChatModel().call(
                .init(
                    index: index,
                    totalCount: input.documents.count,
                    question: input.question,
                    previousAnswer: intermediateAnswer?.answer,
                    document: document.document.pageContent,
                    distance: document.distance
                ),
                callbackManagers: callbackManagers
            )
            intermediateAnswer = extractAnswer(output)

            if let intermediateAnswer {
                callbackManagers.send(
                    \.refineDocumentChainDidGenerateIntermediateAnswer,
                    intermediateAnswer
                )
            }
        }

        return intermediateAnswer?.answer ?? "None"
    }

    public func parseOutput(_ output: String) -> String {
        return output
    }

    func extractAnswer(_ chatMessage: ChatMessage) -> IntermediateAnswer {
        for functionCall in chatMessage.toolCalls?.map(\.function) ?? [] {
            do {
                let intermediateAnswer = try JSONDecoder().decode(
                    IntermediateAnswer.self,
                    from: functionCall.arguments.data(using: .utf8) ?? Data()
                )
                return intermediateAnswer
            } catch {
                let intermediateAnswer = IntermediateAnswer(
                    answer: functionCall.arguments,
                    usefulness: 0,
                    more: true
                )
                return intermediateAnswer
            }
        }
        return .init(answer: chatMessage.content ?? "", usefulness: 0, more: true)
    }
}

public extension CallbackEvents {
    struct RefineDocumentChainDidGenerateIntermediateAnswer: CallbackEvent {
        public let info: RefineDocumentChain.IntermediateAnswer
    }

    var refineDocumentChainDidGenerateIntermediateAnswer:
        RefineDocumentChainDidGenerateIntermediateAnswer.Type
    {
        RefineDocumentChainDidGenerateIntermediateAnswer.self
    }
}

