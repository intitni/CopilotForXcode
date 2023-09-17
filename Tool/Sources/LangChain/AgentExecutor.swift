import Foundation

public protocol AgentOutputParsable {
    static func parse(_ string: String) throws -> Self
    var botReadableContent: String { get }
}

extension String: AgentOutputParsable {
    public static func parse(_ string: String) throws -> String { string }
    public var botReadableContent: String { self }
}

public actor AgentExecutor<InnerAgent: Agent>: Chain
    where InnerAgent.Input == String, InnerAgent.Output: AgentOutputParsable
{
    public typealias Input = String
    public struct Output {
        typealias FinalOutput = AgentFinish<InnerAgent.Output>.ReturnValue

        let finalOutput: FinalOutput
        let intermediateSteps: [AgentAction]
    }

    let agent: InnerAgent
    let tools: [String: AgentTool]
    let maxIteration: Int?
    let maxExecutionTime: Double?
    var earlyStopHandleType: AgentEarlyStopHandleType
    var now: () -> Date = { Date() }
    var isCancelled = false

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
        callbackManagers: [CallbackManager]
    ) async throws -> Output {
        try agent.validateTools(tools: Array(tools.values))

        let startTime = now().timeIntervalSince1970
        var iterations = 0
        var intermediateSteps: [AgentAction] = []

        func shouldContinue() -> Bool {
            if isCancelled { return false }
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
        switch output.finalOutput {
        case let .failure(error): return error
        case let .success(output): return output.botReadableContent
        }
    }

    public func cancel() {
        isCancelled = true
        earlyStopHandleType = .force
    }
}

struct InvalidToolError: Error {}

extension AgentExecutor {
    func end(
        output: AgentFinish<InnerAgent.Output>,
        intermediateSteps: [AgentAction],
        callbackManagers: [CallbackManager]
    ) -> Output {
        for callbackManager in callbackManagers {
            callbackManager.send(CallbackEvents.AgentDidFinish(info: output))
        }
        let finalOutput = output.returnValue
        return .init(finalOutput: finalOutput, intermediateSteps: intermediateSteps)
    }

    /// Plan the scratch pad and let the agent decide what to do next
    func takeNextStep(
        input: Input,
        intermediateSteps: [AgentAction],
        callbackManagers: [CallbackManager]
    ) async throws -> AgentNextStep<InnerAgent.Output> {
        let output = try await agent.plan(
            input: input,
            intermediateSteps: intermediateSteps,
            callbackManagers: callbackManagers
        )
        switch output {
        // If the output says finish, then return the output immediately.
        case .finish: return output
        // If the output contains actions, run them, and append the results to the scratch pad.
        case let .actions(actions):
            let completedActions = try await withThrowingTaskGroup(of: AgentAction.self) {
                taskGroup in
                for action in actions {
                    callbackManagers
                        .forEach { $0.send(CallbackEvents.AgentActionDidStart(info: action)) }
                    guard let tool = tools[action.toolName] else { throw InvalidToolError() }
                    taskGroup.addTask {
                        let observation = try await tool.run(input: action.toolInput)
                        return action.observationAvailable(observation)
                    }
                }
                var completedActions = [AgentAction]()
                for try await action in taskGroup {
                    completedActions.append(action)
                    callbackManagers
                        .forEach { $0.send(CallbackEvents.AgentActionDidEnd(info: action)) }
                }
                return completedActions
            }

            return .actions(completedActions)
        }
    }

    func getToolFinish(action: AgentAction) -> AgentFinish<InnerAgent.Output>? {
        guard let tool = tools[action.toolName] else { return nil }
        guard tool.returnDirectly else { return nil }
        
        do {
            let result = try InnerAgent.Output.parse(action.observation ?? "")
            return .init(returnValue: .success(result), log: action.observation ?? "")
        } catch {
            return .init(
                returnValue: .failure(action.observation ?? "no observation"),
                log: action.observation ?? ""
            )
        }
    }
}

