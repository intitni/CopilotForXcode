import Foundation
import Logger
import OpenAIService
import Preferences

public class CombineAnswersChain: Chain {
    public struct Input: Decodable {
        public var question: String
        public var answers: [String]
        public init(question: String, answers: [String]) {
            self.question = question
            self.answers = answers
        }
    }

    public typealias Output = String
    public let chatModelChain: ChatModelChain<Input>

    public init(
        configuration: ChatGPTConfiguration =
            UserPreferenceChatGPTConfiguration(chatModelKey: \.preferredChatModelIdForUtilities),
        extraInstructions: String = ""
    ) {
        chatModelChain = .init(
            chatModel: OpenAIChat(
                configuration: configuration.overriding {
                    $0.runFunctionsAutomatically = false
                },
                memory: nil,
                stream: false
            ),
            stops: ["Observation:"],
            promptTemplate: { input in
                [
                    .init(
                        role: .system,
                        content: """
                        You are a helpful assistant.
                        Your job is to combine multiple answers from different sources to one question.
                        \(extraInstructions)
                        """
                    ),
                    .init(role: .user, content: """
                    Question: \(input.question)

                    Answers:
                    \(input.answers.joined(separator: "\n\(String(repeating: "-", count: 32))\n"))

                    What is the combined answer?
                    """),
                ]
            }
        )
    }

    public func callLogic(
        _ input: Input,
        callbackManagers: [CallbackManager]
    ) async throws -> String {
        let output = try await chatModelChain.call(input, callbackManagers: callbackManagers)
        return await parseOutput(output)
    }

    public func parseOutput(_ message: ChatMessage) async -> String {
        return message.content ?? "No answer."
    }

    public func parseOutput(_ output: String) -> String {
        output
    }
}

