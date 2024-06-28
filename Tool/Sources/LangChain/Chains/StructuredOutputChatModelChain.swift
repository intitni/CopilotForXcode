import ChatBasic
import Foundation
import Logger
import OpenAIService

/// This is an agent used to get a structured output.
public class StructuredOutputChatModelChain<Output: Decodable>: Chain {
    public struct EndFunction: ChatGPTArgumentsCollectingFunction {
        public struct Arguments: Decodable {
            var finalAnswer: Output
        }

        public var name: String { "FinalAnswer" }
        public var description: String { "Save the final answer when it's ready" }
        public var argumentSchema: JSONSchemaValue {
            return [
                .type: "object",
                .properties: [
                    "finalAnswer": .hash(finalAnswerSchema),
                ],
                .required: ["finalAnswer"],
            ]
        }

        public let finalAnswerSchema: [String: JSONSchemaValue]

        public init(argumentSchema: [String: JSONSchemaValue]) {
            finalAnswerSchema = argumentSchema
        }

        public init() where Output == String {
            finalAnswerSchema = [
                JSONSchemaKey.type.key: "string",
            ]
        }

        public init() where Output == Int {
            finalAnswerSchema = [
                JSONSchemaKey.type.key: "number",
            ]
        }

        public init() where Output == Double {
            finalAnswerSchema = [
                JSONSchemaKey.type.key: "number",
            ]
        }
    }

    struct FunctionProvider: ChatGPTFunctionProvider {
        var endFunction: EndFunction
        var functions: [any ChatGPTFunction] {
            [endFunction]
        }

        var functionCallStrategy: FunctionCallStrategy? {
            .function(name: endFunction.name)
        }
    }

    public typealias Input = String
    public let chatModelChain: ChatModelChain<String>
    var functionProvider: FunctionProvider

    public init(
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration(),
        endFunction: EndFunction,
        promptTemplate: ((String) -> [ChatMessage])? = nil
    ) {
        functionProvider = .init(
            endFunction: endFunction
        )
        chatModelChain = .init(
            chatModel: OpenAIChat(
                configuration: configuration.overriding {
                    $0.runFunctionsAutomatically = false
                },
                memory: nil,
                functionProvider: functionProvider,
                stream: false
            ),
            stops: ["Observation:"],
            promptTemplate: promptTemplate ?? { input in
                [
                    .init(
                        role: .system,
                        content: """
                        You are a helpful assistant
                        Generate a final answer to my query as concisely, helpfully and accurately as possible.
                        You don't ask me for additional information.
                        """
                    ),
                    .init(role: .user, content: input),
                ]
            }
        )
    }

    public func callLogic(
        _ input: String,
        callbackManagers: [CallbackManager]
    ) async throws -> Output? {
        let output = try await chatModelChain.call(input, callbackManagers: callbackManagers)
        return await parseOutput(output)
    }

    public func parseOutput(_ output: Output?) -> String {
        return String(describing: output)
    }

    public func parseOutput(_ message: ChatMessage) async -> Output? {
        if let functionCall = message.toolCalls?.first?.function {
            do {
                let result = try JSONDecoder().decode(
                    EndFunction.Arguments.self,
                    from: functionCall.arguments.data(using: .utf8) ?? Data()
                )
                return result.finalAnswer
            } catch {
                return nil
            }
        }

        return nil
    }
}

