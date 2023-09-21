import Foundation

public actor AgentExecutor<InnerAgent: Agent>: Chain
    where InnerAgent.Input == String, InnerAgent.Output: AgentOutputParsable
{
    public typealias Input = String
    public struct Output {
        public typealias FinalOutput = AgentFinish<InnerAgent.Output>.ReturnValue

        public let finalOutput: FinalOutput
        let intermediateSteps: [AgentAction]
    }

    let agent: InnerAgent
    let tools: [String: AgentTool]
    let maxIteration: Int?
    let maxExecutionTime: Double?
    var earlyStopHandleType: AgentEarlyStopHandleType
    var now: () -> Date = { Date() }
    var isCancelled = false
    var initialSteps: [AgentAction]

    public init(
        agent: InnerAgent,
        tools: [AgentTool],
        maxIteration: Int? = 10,
        maxExecutionTime: Double? = nil,
        earlyStopHandleType: AgentEarlyStopHandleType = .generate,
        initialSteps: [AgentAction] = []
    ) {
        self.agent = agent
        self.tools = tools.reduce(into: [:]) { $0[$1.name] = $1 }
        self.maxIteration = maxIteration
        self.maxExecutionTime = maxExecutionTime
        self.earlyStopHandleType = earlyStopHandleType
        self.initialSteps = initialSteps
    }

    public func callLogic(
        _ input: Input,
        callbackManagers: [CallbackManager]
    ) async throws -> Output {
        try agent.validateTools(tools: Array(tools.values))

        let startTime = now().timeIntervalSince1970
        var iterations = 0
        var intermediateSteps: [AgentAction] = initialSteps

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
            try Task.checkCancellation()
            let nextStepOutput = try await takeNextStep(
                input: input,
                intermediateSteps: intermediateSteps,
                callbackManagers: callbackManagers
            )

            try Task.checkCancellation()
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
        case let .unstructured(error): return error
        case let .structured(output): return output.botReadableContent
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
                    callbackManagers.send(CallbackEvents.AgentActionDidStart(info: action))
                    if action.observation != nil {
                        taskGroup.addTask { action }
                        continue
                    }
                    guard let tool = tools[action.toolName] else { throw InvalidToolError() }
                    taskGroup.addTask {
                        do {
                            let observation = try await tool.run(input: action.toolInput)
                            return action.observationAvailable(observation)
                        } catch {
                            let observation = error.localizedDescription
                            return action.observationAvailable(observation)
                        }
                    }
                }
                var completedActions = [AgentAction]()
                for try await action in taskGroup {
                    try Task.checkCancellation()
                    completedActions.append(action)
                    callbackManagers.send(CallbackEvents.AgentActionDidEnd(info: action))
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
            return .init(returnValue: .structured(result), log: action.observation ?? "")
        } catch {
            return .init(
                returnValue: .unstructured(action.observation ?? "no observation"),
                log: action.observation ?? ""
            )
        }
    }
}

// MARK: - AgentOutputParsable

public protocol AgentOutputParsable {
    static func parse(_ string: String) throws -> Self
    var botReadableContent: String { get }
}

extension String: AgentOutputParsable {
    public static func parse(_ string: String) throws -> String { string }
    public var botReadableContent: String { self }
}

extension Int: AgentOutputParsable {
    public static func parse(_ string: String) throws -> Int {
        guard let int = Int(string) else { return 0 }
        return int
    }

    public var botReadableContent: String { String(self) }
}

extension Double: AgentOutputParsable {
    public static func parse(_ string: String) throws -> Double {
        guard let double = Double(string) else { return 0 }
        return double
    }

    public var botReadableContent: String { String(self) }
}

