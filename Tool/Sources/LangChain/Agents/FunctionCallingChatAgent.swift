import Foundation
import Logger
import OpenAIService

public class FunctionCallingChatAgent<Output: AgentOutputParsable & Decodable>: Agent {
    public typealias ScratchPadContent = [ChatMessage]

    public struct EndFunction: ChatGPTFunction {
        public typealias Argument = Output
        public typealias Result = String
        public var name: String { "saveFinalAnswer" }
        public var description: String { "Save the final answer when it's ready" }
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
    public let chatModelChain: ChatModelChain<AgentInput<String, ScratchPadContent>>
    var functionProvider: FunctionProvider

    public init(
        configuration: ChatGPTConfiguration = UserPreferenceChatGPTConfiguration(),
        tools: [AgentTool] = [],
        endFunction: EndFunction,
        extraSystemPrompt: String = ""
    ) {
        let functions = tools.compactMap { $0 as? (any ChatGPTFunction) }
        let otherTools = tools.filter { !($0 is (any ChatGPTFunction)) }
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
                        Gather information using functions, and generate a final answer to my query as concisely, helpfully and accurately as possible.
                        You don't ask me for additional information.
                        \(extraSystemPrompt)
                        When you have the final answer, you MUST call `\(endFunction.name)` to save it.
                        """
                    ),
                    .init(role: .user, content: agentInput.input),
                ] + agentInput.thoughts.content
            }
        )
    }

    public func extraPlan(input: AgentInput<String, ScratchPadContent>) {
        // no extra plan
    }
    
    func constructBaseScratchpad(
        intermediateSteps: [AgentAction]
    ) -> ScratchPadContent {
        return intermediateSteps.flatMap {
            if let observation = $0.observation {
                return [
                    ChatMessage(
                        role: .assistant,
                        content: nil,
                        functionCall: .init(name: $0.toolName, arguments: $0.toolInput)
                    ),
                    ChatMessage(role: .function, content: observation, name: $0.toolName),
                ]
            }
            return [
                ChatMessage(role: .assistant, content: $0.toolInput),
                ChatMessage(
                    role: .user,
                    content: "Please continue, call \(functionProvider.endFunction.name) when you are done."
                ),
            ]
        }
    }

    public func constructScratchpad(
        intermediateSteps: [AgentAction]
    ) -> AgentScratchPad<ScratchPadContent> {
        functionProvider.shouldFinish = false
        let baseScratchpad = constructBaseScratchpad(intermediateSteps: intermediateSteps)
        return .init(content: baseScratchpad)
    }

    public func constructFinalScratchpad(
        intermediateSteps: [AgentAction]
    ) -> AgentScratchPad<ScratchPadContent> {
        functionProvider.shouldFinish = true
        let baseScratchpad = constructBaseScratchpad(intermediateSteps: intermediateSteps)
        return .init(content: baseScratchpad + [
            ChatMessage(role: .assistant, content: "Now I need to save the final answer"),
            ChatMessage(role: .user, content: "Please continue"),
        ])
    }

    public func validateTools(tools: [AgentTool]) throws {
        // no validation
    }

    public func parseOutput(_ message: ChatMessage) async -> AgentNextStep<Output> {
        if let functionCall = message.functionCall {
            if let function = functionProvider.functions.first(where: {
                $0.name == functionCall.name
            }) {
                if function.name == functionProvider.endFunction.name {
                    do {
                        let output = try Output.parse(functionCall.arguments)
                        return .finish(.init(
                            returnValue: .structured(output),
                            log: functionCall.arguments
                        ))
                    } catch {
                        return .finish(.init(
                            returnValue: .unstructured(error.localizedDescription),
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
            case let .unstructured(x), let .structured(x):
                return .finish(.init(returnValue: .unstructured(x), log: finish.log))
            }
        case let .thought(content):
            return .finish(.init(returnValue: .unstructured(content), log: content))
        }
    }
}

