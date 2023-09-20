import Foundation
import Logger
import OpenAIService

/// This is an agent used to get a structured output.
public class StructuredOutputChatModelChain<Output: Decodable>: Chain {
    public struct EndFunction: ChatGPTArgumentsCollectingFunction {
        public typealias Arguments = Output
        public var name: String { "saveFinalAnswer" }
        public var description: String { "Save the final answer when it's ready" }
        public let argumentSchema: JSONSchemaValue
        public init(argumentSchema: JSONSchemaValue) {
            self.argumentSchema = argumentSchema
        }
    }

    struct FunctionProvider: ChatGPTFunctionProvider {
        var endFunction: EndFunction
        var functions: [any ChatGPTFunction] {
            [endFunction]
        }

        var functionCallStrategy: FunctionCallStrategy? {
            .name(endFunction.name)
        }
    }

    public typealias Input = String
    public let chatModelChain: ChatModelChain<String>
    var functionProvider: FunctionProvider

    public init(
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration(),
        tools: [AgentTool] = [],
        endFunction: EndFunction,
        extraSystemPrompt: String = ""
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
            promptTemplate: { input in
                [
                    .init(
                        role: .system,
                        content: """
                        You are a helpful assistant
                        Generate a final answer to my query as concisely, helpfully and accurately as possible.
                        You don't ask me for additional information.
                        \(extraSystemPrompt)
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
        if let functionCall = message.functionCall {
            if let function = functionProvider.functions.first(where: {
                $0.name == functionCall.name
            }) {
                if function.name == functionProvider.endFunction.name {
                    do {
                        let result = try JSONDecoder().decode(
                            Output.self,
                            from: functionCall.arguments.data(using: .utf8) ?? Data()
                        )
                        return result
                    } catch {
                        return nil
                    }
                }
            }
        }

        return nil
    }
}

