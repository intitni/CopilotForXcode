import Foundation
import OpenAIService

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
        var functionCallStrategy: FunctionCallStrategy? = .auto
        var functions: [any ChatGPTFunction] = [NoneFunction()]
    }

    struct NoneFunction: ChatGPTArgumentsCollectingFunction {
        typealias Arguments = NoArguments
        var name: String = "noInformationFound"
        var description: String = "Call when you can't find any relevant information from the document, or the question was not mentioned in the document"
    }

    func buildChatModel() -> ChatModelChain<TaskInput> {
        .init(
            chatModel: OpenAIChat(
                configuration: UserPreferenceChatGPTConfiguration().overriding {
                    $0.temperature = 0
                    $0.runFunctionsAutomatically = false
                },
                memory: EmptyChatGPTMemory(),
                functionProvider: FunctionProvider(),
                stream: false
            )
        ) { input in [
            .init(
                role: .system,
                content: """
                Extract the relevant information from the Document according to the Question.
                Make the information clear, concise and short.
                If found code, wrap it in markdown code block.
                """
            ),
            .init(
                role: .user,
                content: """
                Question:###
                \(input.question)
                ###
                Document:###
                \(input.document)
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
