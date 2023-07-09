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

public struct AgentFinish: Equatable {
    public var returnValue: String
    public var log: String

    public init(returnValue: String, log: String) {
        self.returnValue = returnValue
        self.log = log
    }
}

public enum AgentNextStep: Equatable {
    case actions([AgentAction])
    case finish(AgentFinish)
}

public enum AgentScratchPad: Equatable {
    case text(String)
    case messages([String])
    
    var isEmpty: Bool {
        switch self {
        case .text(let text):
            return text.isEmpty
        case .messages(let messages):
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
    var chatModelChain: ChatModelChain<AgentInput<Input>> { get }
    var observationPrefix: String { get }
    var llmPrefix: String { get }

    func validateTools(tools: [AgentTool]) throws
    func constructScratchpad(intermediateSteps: [AgentAction]) -> AgentScratchPad
    func parseOutput(_ output: String) -> AgentNextStep
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
    ) async throws -> AgentNextStep {
        let input = getFullInputs(input: input, intermediateSteps: intermediateSteps)
        let output = try await chatModelChain.call(input, callbackManagers: callbackManagers)
        return parseOutput(output)
    }

    func returnStoppedResponse(
        input: Input,
        earlyStoppedHandleType: AgentEarlyStopHandleType,
        intermediateSteps: [AgentAction],
        callbackManagers: [CallbackManager]
    ) async throws -> AgentFinish {
        switch earlyStoppedHandleType {
        case .force:
            return AgentFinish(
                returnValue: "Agent stopped due to iteration limit or time limit.",
                log: ""
            )
        case .generate:
            var thoughts = constructBaseScratchpad(intermediateSteps: intermediateSteps)
            thoughts += """
            
            \(llmPrefix)I now need to return a final answer based on the previous steps:
            (Please continue with `Final Answer:`)
            """
            let input = AgentInput(input: input, thoughts: .text(thoughts))
            let output = try await chatModelChain.call(input, callbackManagers: callbackManagers)
            let nextAction = parseOutput(output)
            switch nextAction {
            case let .finish(finish):
                return finish
            case .actions:
                return AgentFinish(returnValue: output, log: output)
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

