import ChatBasic
import Foundation
import OpenAIService
import Preferences

public final class RelevantInformationExtractionChain: Chain {
    public struct Input {
        var question: String
        var documents: [(document: Document, distance: Float)]
    }

    struct TaskInput {
        var question: String
        var document: Document
    }

    public typealias Output = String

    class FunctionProvider: ChatGPTFunctionProvider {
        var functionCallStrategy: FunctionCallStrategy? = .function(name: "saveFinalAnswer")
        var functions: [any ChatGPTFunction] = [FinalAnswer()]
    }

    struct FinalAnswer: ChatGPTArgumentsCollectingFunction {
        struct Arguments: Decodable {
            var relevantInformation: String
            var noRelevantInformationFound: Bool?
        }

        var name: String = "saveFinalAnswer"
        var description: String =
            "save the relevant information"
        var argumentSchema: JSONSchemaValue {
            [
                .type: "object",
                .properties: [
                    "relevantInformation": [.type: "string"],
                    "noRelevantInformationFound": [.type: "boolean"],
                ],
                .required: ["relevantInformation", "noRelevantInformationFound"],
            ]
        }
    }

    let filterMetadata: (String) -> Bool
    let hint: String

    init(filterMetadata: @escaping (String) -> Bool = { _ in true }, hint: String) {
        self.filterMetadata = filterMetadata
        self.hint = hint
    }

    func buildChatModel() -> ChatModelChain<TaskInput> {
        .init(
            chatModel: OpenAIChat(
                configuration: UserPreferenceChatGPTConfiguration(
                    chatModelKey: \.preferredChatModelIdForUtilities
                )
                .overriding {
                    $0.temperature = 0.5
                    $0.runFunctionsAutomatically = false
                },
                memory: EmptyChatGPTMemory(),
                functionProvider: FunctionProvider(),
                stream: false
            )
        ) { [filterMetadata, hint] input in [
            .init(
                role: .system,
                content: """
                Extract the relevant information from the Document according to the Question.
                The information may not directly answer the question, but it should be relevant to the question, \
                please think carefully and make you decision.
                Make the information clear, concise and short.
                If found code, wrap it in markdown code block.
                \(hint)
                """
            ),
            .init(
                role: .user,
                content: """
                Question:###
                (how, when, what or why)
                \(input.question)
                ###
                Document:###
                \(input.document.metadata.filter { key, _ in
                    filterMetadata(key)
                })
                \(input.document.pageContent)
                ###
                """
            ),
        ] }
    }

    public func callLogic(
        _ input: Input,
        callbackManagers: [CallbackManager]
    ) async throws -> Output {
        await withTaskGroup(of: String.self) { group in
            for document in input.documents {
                let taskInput = TaskInput(question: input.question, document: document.document)
                group.addTask {
                    func run() async throws -> String {
                        let model = self.buildChatModel()
                        let output = try await model.call(
                            taskInput,
                            callbackManagers: callbackManagers
                        )

                        if let functionCall = output.toolCalls?
                            .first(where: { $0.function.name == FinalAnswer().name })?.function
                        {
                            do {
                                let arguments = try JSONDecoder().decode(
                                    FinalAnswer.Arguments.self,
                                    from: functionCall.arguments.data(using: .utf8) ?? Data()
                                )
                                if arguments.noRelevantInformationFound ?? false {
                                    return ""
                                }
                                return arguments.relevantInformation
                            } catch {
                                return output.content ?? ""
                            }
                        }

                        return output.content ?? ""
                    }

                    var repeatCount = 0
                    while repeatCount < 3 {
                        do {
                            return try await run()
                        } catch {
                            repeatCount += 1
                        }
                    }
                    return ""
                }
            }

            var results = [String]()
            for await output in group where !output.isEmpty {
                callbackManagers.send(
                    \.relevantInformationExtractionChainDidExtractPartialRelevantContent,
                    output
                )
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if results.contains(trimmed) { continue }
                results.append(trimmed)
            }
            if results.isEmpty { return "No information found." }
            return results.joined(separator: "")
        }
    }

    public func parseOutput(_ output: Output) -> String {
        return output
    }
}

public extension CallbackEvents {
    struct RelevantInformationExtractionChainDidExtractPartialRelevantContent: CallbackEvent {
        public let info: String
    }

    var relevantInformationExtractionChainDidExtractPartialRelevantContent:
        RelevantInformationExtractionChainDidExtractPartialRelevantContent.Type
    {
        RelevantInformationExtractionChainDidExtractPartialRelevantContent.self
    }
}

