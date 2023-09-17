import Foundation
import Logger
import OpenAIService

public class FunctionCallingChatAgent<Output: AgentOutputParsable & Decodable>: Agent {
    public struct EndFunction: ChatGPTFunction {
        public typealias Argument = Output
        public typealias Result = String
        public var name: String { "sendFinalAnswer" }
        public var description: String { "Send the final answer to user" }
        public let argumentSchema: JSONSchemaValue
        public var reportProgress: (String) async -> Void = { _ in }
        public func prepare() async {}
        public func call(arguments: Argument) async throws -> Result { "" }
        public init(argumentSchema: JSONSchemaValue) {
            self.argumentSchema = argumentSchema
        }
    }

    public struct OtherToolFunction: ChatGPTFunction {
        public struct Argument: Decodable {
            public var __arg1: String
        }

        public typealias Result = String
        public var name: String { tool.name }
        public var description: String { tool.description }
        public var argumentSchema: JSONSchemaValue { [
            .type: "object",
            // This is a hack to get around the fact that some tools
            // do not expose an args_schema, and expect an argument
            // which is a string.
            // And Open AI does not support an array type for the
            // parameters.
            .properties: [
                "__arg1": [
                    "title": "__arg1",
                    .type: "string",
                ],
            ],
            .required: ["__arg1"],
        ] }
        public var reportProgress: (String) async -> Void = { _ in }
        public func prepare() async {}
        public func call(arguments: Argument) async throws -> Result {
            try await tool.run(input: arguments.__arg1)
        }

        let tool: AgentTool
        public init(tool: AgentTool) {
            self.tool = tool
        }
    }

    struct FunctionProvider: ChatGPTFunctionProvider {
        var tools: [AgentTool] = []
        var functionTools: [any ChatGPTFunction] = []
        var endFunction: EndFunction
        var functions: [any ChatGPTFunction] {
            shouldFinish
                ? [endFunction]
                : functionTools + tools.map(OtherToolFunction.init) + [endFunction]
        }

        var shouldFinish = false
        var functionCallStrategy: FunctionCallStrategy? {
            shouldFinish ? .name(endFunction.name) : nil
        }
    }

    public typealias Input = String
    public var observationPrefix: String { "Observation: " }
    public var llmPrefix: String { "Thought: " }
    public let chatModelChain: ChatModelChain<AgentInput<String>>
    var functionProvider: FunctionProvider

    public init(
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration(),
        tools: [AgentTool] = [],
        endFunction: EndFunction
    ) {
        let functions = tools.compactMap { $0 as? FunctionCallingAgentTool }.map(\.function)
        let otherTools = tools.filter { !($0 is FunctionCallingAgentTool) }
        functionProvider = .init(
            tools: otherTools,
            functionTools: functions,
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

    public func prepareForEarlyStopWithGenerate() -> String {
        functionProvider.shouldFinish = true
        return "(call sendFinalAnswer to finish)"
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

    public func parseOutput(_ message: ChatMessage) async -> AgentNextStep<Output> {
        if message.role == .assistant, let functionCall = message.functionCall {
            if let function = functionProvider.functionTools.first(where: {
                $0.name == functionCall.name
            }) {
                if function.name == functionProvider.endFunction.name {
                    do {
                        let output = try Output.parse(functionCall.arguments)
                        return .finish(.init(
                            returnValue: .success(output),
                            log: functionCall.arguments
                        ))
                    } catch {
                        return .finish(.init(
                            returnValue: .failure(error.localizedDescription),
                            log: functionCall.arguments
                        ))
                    }
                } else {
                    return .actions([
                        .init(
                            toolName: function.name,
                            toolInput: functionCall.arguments,
                            log: functionCall.arguments
                        ),
                    ])
                }
            }
        }
        
        // fallback to normal agent.

        let stringBaseOutput = await ChatAgent(
            chatModel: chatModelChain.chatModel,
            tools: functionProvider.tools,
            preferredLanguage: ""
        ).parseOutput(message)

        switch stringBaseOutput {
        case let .actions(actions):
            return .actions(actions)
        case let .finish(finish):
            switch finish.returnValue {
            case let .failure(x), let .success(x):
                return .finish(.init(returnValue: .failure(x), log: finish.log))
            }
        }
    }
}

