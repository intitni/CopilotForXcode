import ChatBasic
import Foundation
import OpenAIService

public protocol AgentTool {
    var name: String { get }
    var description: String { get }
    var returnDirectly: Bool { get }
    func run(input: String) async throws -> String
}

public struct SimpleAgentTool: AgentTool {
    public let name: String
    public let description: String
    public let returnDirectly: Bool
    public let run: (String) async throws -> String

    public init(
        name: String,
        description: String,
        returnDirectly: Bool = false,
        run: @escaping (String) async throws -> String
    ) {
        self.name = name
        self.description = description
        self.returnDirectly = returnDirectly
        self.run = run
    }

    public func run(input: String) async throws -> String {
        try await run(input)
    }
}

public class FunctionCallingAgentTool<F: ChatGPTFunction>: AgentTool, ChatGPTFunction {
    public func call(arguments: F.Arguments) async throws -> F.Result {
        try await function.call(arguments: arguments, reportProgress: reportProgress)
    }

    public var argumentSchema: ChatBasic.JSONSchemaValue { function.argumentSchema }

    public typealias Arguments = F.Arguments
    public typealias Result = F.Result

    public var function: F
    public var name: String
    public var description: String
    public var returnDirectly: Bool

    let callbackManagers: [CallbackManager]

    public init(
        function: F,
        returnDirectly: Bool = false,
        callbackManagers: [CallbackManager] = []
    ) {
        self.function = function
        self.callbackManagers = callbackManagers
        name = function.name
        description = function.description
        self.returnDirectly = returnDirectly
    }

    func reportProgress(_ progress: String) {
        callbackManagers.send(
            CallbackEvents.AgentFunctionCallingToolReportProgress(info: .init(
                functionName: name,
                progress: progress
            ))
        )
    }

    public func run(input: String) async throws -> String {
        await prepare(reportProgress: { [weak self] p in
            self?.reportProgress(p)
        })
        return try await call(
            argumentsJsonString: input,
            reportProgress: { [weak self] p in
                self?.reportProgress(p)
            }
        )
        .botReadableContent
    }

    public func prepare(reportProgress: @escaping ReportProgress) async {
        await function.prepare(reportProgress: { [weak self] p in
            self?.reportProgress(p)
        })
    }

    public func call(
        arguments: F.Arguments,
        reportProgress: @escaping ReportProgress
    ) async throws -> F.Result {
        try await function.call(arguments: arguments, reportProgress: reportProgress)
    }
}

