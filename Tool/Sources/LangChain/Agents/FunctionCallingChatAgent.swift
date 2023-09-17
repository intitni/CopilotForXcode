import Foundation
import Logger
import OpenAIService

public class FunctionCallingChatAgent: Agent {
    struct EndFunction: ChatGPTFunction {
        struct Argument: Codable {
            let finalAnswer: String
        }

        typealias Result = String

        var name: String { "sendFinalAnswer" }
        var description: String { "Send the final answer to user" }
        var argumentSchema: JSONSchemaValue {
            [
                .type: "object",
                .properties: [
                    "finalAnswer": [
                        .type: "string",
                        .description: "the final answer to send to user",
                    ],
                ],
                .required: ["finalAnswer"],
            ]
        }

        var reportProgress: (String) async -> Void = { _ in }
        func prepare() async {}
        func call(arguments: Argument) async throws -> Result {
            return arguments.finalAnswer
        }
    }

    struct FunctionProvider: ChatGPTFunctionProvider {
        var tools: [AgentTool] = []
        var functionTools: [any ChatGPTFunction] = []
        var functions: [any ChatGPTFunction] {
            functionTools + [EndFunction()]
        }

        var functionCallStrategy: FunctionCallStrategy? = nil
    }

    public typealias Input = String
    public var observationPrefix: String { "Observation: " }
    public var llmPrefix: String { "Thought: " }
    public let chatModelChain: ChatModelChain<AgentInput<String>>
    var functionProvider: FunctionProvider

    public init(
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration(),
        memory: ChatGPTMemory = ConversationChatGPTMemory(systemPrompt: ""),
        functions: [any ChatGPTFunction] = [],
        tools: [AgentTool] = []
    ) {
        functionProvider = .init(tools: tools, functionTools: functions)
        chatModelChain = .init(
            chatModel: OpenAIChat(
                configuration: configuration.overriding {
                    $0.runFunctionsAutomatically = false
                },
                memory: memory,
                functionProvider: functionProvider,
                stream: false
            ),
            stops: ["Observation:"],
            promptTemplate: { agentInput in
                [
                    .init(
                        role: .system,
                        content: """
                        Respond to the human as helpfully and accurately as possible. \
                        Format final answer to be more readable, in a ordered list if possible. \

                        Begin!
                        """
                    ),
                    agentInput.thoughts.isEmpty
                        ? .init(role: .user, content: agentInput.input)
                        : .init(
                            role: .user,
                            content: """
                            \(agentInput.input)

                            \({
                                switch agentInput.thoughts {
                                case let .text(text):
                                    return text
                                case let .messages(messages):
                                    return messages.map { message in
                                        """
                                        \(message)
                                        """
                                    }.joined(separator: "\n")
                                }
                            }())
                            """
                        ),
                ]
            }
        )
    }

    public func extraPlan(input: AgentInput<String>) {
        // no extra plan
    }

    public func prepareForEarlyStopWithGenerate() {
        functionProvider.functionTools = []
        functionProvider.tools = []
        functionProvider.functionCallStrategy = .name("finalAnswer")
    }

    public func constructScratchpad(intermediateSteps: [AgentAction]) -> AgentScratchPad {
        let baseScratchpad = constructBaseScratchpad(intermediateSteps: intermediateSteps)
        if baseScratchpad.isEmpty { return .text("") }
        return .text("""
        This was your previous work (but I haven't seen any of it! I only see what you return as `Final Answer`):
        \(baseScratchpad)
        (Please continue with `Thought:` or call a function)
        """)
    }

    public func validateTools(tools: [AgentTool]) throws {
        // no validation
    }

    public func parseOutput(_ message: ChatMessage) async -> AgentNextStep {
        if message.role == .function, let functionCall = message.functionCall {
            if let function = functionProvider.functionTools.first(where: {
                $0.name == functionCall.name
            }) {
                do {
                    let result = try await function
                        .call(argumentsJsonString: functionCall.arguments)
                    return .actions([.init(
                        toolName: functionCall.name,
                        toolInput: result.botReadableContent,
                        log: result.botReadableContent
                    )])
                } catch {
                    return .actions([.init(
                        toolName: functionCall.name,
                        toolInput: error.localizedDescription,
                        log: error.localizedDescription
                    )])
                }
            }
        }

        return await ChatAgent(
            chatModel: chatModelChain.chatModel,
            tools: functionProvider.tools,
            preferredLanguage: ""
        )
        .parseOutput(message)
    }
}

