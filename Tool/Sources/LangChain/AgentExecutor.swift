import Foundation

public protocol ChainCallbackManager {
    func onChainStart<T: Chain>(type: T.Type, input: T.Input)
    func onAgentFinish(output: AgentFinish)
    func onAgentActionStart(action: AgentAction)
    func onAgentActionEnd(action: AgentAction)
    func onLLMNewToken(token: String)
}

public actor AgentExecutor<InnerAgent: Agent>: Chain where InnerAgent.Input == String {
    public typealias Input = String
    public struct Output {
        let finalOutput: String
        let intermediateSteps: [AgentAction]
    }

    let agent: InnerAgent
    let tools: [String: AgentTool]
    let maxIteration: Int?
    let maxExecutionTime: Double?
    let earlyStopHandleType: AgentEarlyStopHandleType
    var now: () -> Date = { Date() }

    public init(
        agent: InnerAgent,
        tools: [AgentTool],
        maxIteration: Int? = 10,
        maxExecutionTime: Double? = nil,
        earlyStopHandleType: AgentEarlyStopHandleType = .force
    ) {
        self.agent = agent
        self.tools = tools.reduce(into: [:]) { $0[$1.name] = $1 }
        self.maxIteration = maxIteration
        self.maxExecutionTime = maxExecutionTime
        self.earlyStopHandleType = earlyStopHandleType
    }

    public func callLogic(
        _ input: Input,
        callbackManagers: [ChainCallbackManager]
    ) async throws -> Output {
        try agent.validateTools(tools: Array(tools.values))

        let startTime = now().timeIntervalSince1970
        var iterations = 0
        var intermediateSteps: [AgentAction] = []

        func shouldContinue() -> Bool {
            if let maxIteration = maxIteration, iterations >= maxIteration {
                return false
            }
            if let maxExecutionTime = maxExecutionTime,
               now().timeIntervalSince1970 - startTime > maxExecutionTime
            {
                return false
            }
            return true
        }

        while shouldContinue() {
            let nextStepOutput = try await takeNextStep(
                input: input,
                intermediateSteps: intermediateSteps,
                callbackManagers: callbackManagers
            )

            switch nextStepOutput {
            case let .finish(finish):
                return end(
                    output: finish,
                    intermediateSteps: intermediateSteps,
                    callbackManagers: callbackManagers
                )
            case let .actions(actions):
                intermediateSteps.append(contentsOf: actions)
                if actions.count == 1,
                   let action = actions.first,
                   let toolFinish = getToolFinish(action: action)
                {
                    return end(
                        output: toolFinish,
                        intermediateSteps: intermediateSteps,
                        callbackManagers: callbackManagers
                    )
                }
            }
            iterations += 1
        }

        let output = try await agent.returnStoppedResponse(
            input: input,
            earlyStoppedHandleType: earlyStopHandleType,
            intermediateSteps: intermediateSteps,
            callbackManagers: callbackManagers
        )
        return end(
            output: output,
            intermediateSteps: intermediateSteps,
            callbackManagers: callbackManagers
        )
    }

    public nonisolated func parseOutput(_ output: Output) -> String {
        output.finalOutput
    }
}

struct InvalidToolError: Error {}

extension AgentExecutor {
    func end(
        output: AgentFinish,
        intermediateSteps: [AgentAction],
        callbackManagers: [ChainCallbackManager]
    ) -> Output {
        for callbackManager in callbackManagers {
            callbackManager.onAgentFinish(output: output)
        }
        let finalOutput = output.returnValue
        return .init(finalOutput: finalOutput, intermediateSteps: intermediateSteps)
    }

    func takeNextStep(
        input: Input,
        intermediateSteps: [AgentAction],
        callbackManagers: [ChainCallbackManager]
    ) async throws -> AgentNextStep {
        let output = try await agent.plan(
            input: input,
            intermediateSteps: intermediateSteps,
            callbackManagers: callbackManagers
        )
        switch output {
        case .finish: return output
        case let .actions(actions):
            let completedActions = try await withThrowingTaskGroup(of: AgentAction.self) {
                taskGroup in
                for action in actions {
                    callbackManagers.forEach { $0.onAgentActionStart(action: action) }
                    guard let tool = tools[action.toolName] else { throw InvalidToolError() }
                    taskGroup.addTask {
                        let observation = try await tool.run(input: action.toolInput)
                        return action.observationAvailable(observation)
                    }
                }
                var completedActions = [AgentAction]()
                for try await action in taskGroup {
                    completedActions.append(action)
                    callbackManagers.forEach { $0.onAgentActionEnd(action: action) }
                }
                return completedActions
            }

            return .actions(completedActions)
        }
    }

    func getToolFinish(action: AgentAction) -> AgentFinish? {
        guard let tool = tools[action.toolName] else { return nil }
        guard tool.returnDirectly else { return nil }
        return .init(returnValue: action.observation ?? "", log: "")
    }
}

