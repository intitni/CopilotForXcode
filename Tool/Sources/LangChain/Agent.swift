import Foundation

public struct AgentAction: Equatable {
    public var toolName: String
    public var toolInput: String
    public var log: String
    public var observation: String?

    public init(toolName: String, toolInput: String, log: String, observation: String? = nil) {
        self.toolName = toolName
        self.toolInput = toolInput
        self.log = log
        self.observation = observation
    }

    public func observationAvailable(_ observation: String) -> AgentAction {
        var newAction = self
        newAction.observation = observation
        return newAction
    }
}

public extension CallbackEvents {
    struct AgentDidFinish<Output: AgentOutputParsable>: CallbackEvent {
        public let info: AgentFinish<Output>
    }

    func agentDidFinish<Output: AgentOutputParsable>() -> AgentDidFinish<Output>.Type {
        AgentDidFinish<Output>.self
    }

    struct AgentActionDidStart: CallbackEvent {
        public let info: AgentAction
    }

    var agentActionDidStart: AgentActionDidStart.Type {
        AgentActionDidStart.self
    }

    struct AgentActionDidEnd: CallbackEvent {
        public let info: AgentAction
    }

    var agentActionDidEnd: AgentActionDidEnd.Type {
        AgentActionDidEnd.self
    }
}

public struct AgentFinish<Output: AgentOutputParsable> {
    public enum ReturnValue {
        case success(Output)
        case failure(String)
    }

    public var returnValue: ReturnValue
    public var log: String

    public init(returnValue: ReturnValue, log: String) {
        self.returnValue = returnValue
        self.log = log
    }
}

public enum AgentNextStep<Output: AgentOutputParsable> {
    case actions([AgentAction])
    case finish(AgentFinish<Output>)
}

public enum AgentScratchPad: Equatable {
    case text(String)
    case messages([String])

    var isEmpty: Bool {
        switch self {
        case let .text(text):
            return text.isEmpty
        case let .messages(messages):
            return messages.isEmpty
        }
    }
}

public struct AgentInput<T> {
    var input: T
    var thoughts: AgentScratchPad

    public init(input: T, thoughts: AgentScratchPad) {
        self.input = input
        self.thoughts = thoughts
    }
}

extension AgentInput: Equatable where T: Equatable {}

public enum AgentEarlyStopHandleType: Equatable {
    case force
    case generate
}

public protocol Agent {
    associatedtype Input
    associatedtype Output: AgentOutputParsable
    var chatModelChain: ChatModelChain<AgentInput<Input>> { get }
    var observationPrefix: String { get }
    var llmPrefix: String { get }

    func validateTools(tools: [AgentTool]) throws
    func constructScratchpad(intermediateSteps: [AgentAction]) -> AgentScratchPad
    func extraPlan(input: AgentInput<Input>)
    func prepareForEarlyStopWithGenerate() -> String
    func parseOutput(_ output: ChatModelChain<AgentInput<Input>>.Output) async
        -> AgentNextStep<Output>
}

public extension Agent {
    func getFullInputs(input: Input, intermediateSteps: [AgentAction]) -> AgentInput<Input> {
        let thoughts = constructScratchpad(intermediateSteps: intermediateSteps)
        return AgentInput(input: input, thoughts: thoughts)
    }

    func plan(
        input: Input,
        intermediateSteps: [AgentAction],
        callbackManagers: [CallbackManager]
    ) async throws -> AgentNextStep<Output> {
        let input = getFullInputs(input: input, intermediateSteps: intermediateSteps)
        extraPlan(input: input)
        let output = try await chatModelChain.call(input, callbackManagers: callbackManagers)
        return await parseOutput(output)
    }

    func returnStoppedResponse(
        input: Input,
        earlyStoppedHandleType: AgentEarlyStopHandleType,
        intermediateSteps: [AgentAction],
        callbackManagers: [CallbackManager]
    ) async throws -> AgentFinish<Output> {
        switch earlyStoppedHandleType {
        case .force:
            return AgentFinish(
                returnValue: .failure("Agent stopped due to iteration limit or time limit."),
                log: ""
            )
        case .generate:
            var thoughts = constructBaseScratchpad(intermediateSteps: intermediateSteps)
            thoughts += """

            \(llmPrefix)I now need to return a final answer based on the previous steps:
            \(prepareForEarlyStopWithGenerate())
            """
            let input = AgentInput(input: input, thoughts: .text(thoughts))
            
            let output = try await chatModelChain.call(input, callbackManagers: callbackManagers)
            let nextAction = await parseOutput(output)
            switch nextAction {
            case let .finish(finish):
                return finish
            case .actions:
                return .init(returnValue: .failure(output.content ?? ""), log: output.content ?? "")
            }
        }
    }

    func constructBaseScratchpad(intermediateSteps: [AgentAction]) -> String {
        var thoughts = ""
        for step in intermediateSteps {
            thoughts += """
            \(step.log)
            \(observationPrefix)\(step.observation ?? "")
            """
        }
        return thoughts
    }
}

