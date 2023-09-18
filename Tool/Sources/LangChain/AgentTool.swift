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

public struct FunctionCallingAgentTool<F: ChatGPTFunction>: AgentTool, ChatGPTFunction {
    public func call(arguments: F.Arguments) async throws -> F.Result {
        try await function.call(arguments: arguments)
    }

    public var argumentSchema: OpenAIService.JSONSchemaValue { function.argumentSchema }

    public func prepare() async { await function.prepare() }

    public var reportProgress: (String) async -> Void {
        get { function.reportProgress }
        set { function.reportProgress = newValue }
    }

    public typealias Arguments = F.Arguments
    public typealias Result = F.Result

    public var function: F
    public var name: String
    public var description: String
    public var returnDirectly: Bool

    public init(function: F, returnDirectly: Bool = false) {
        self.function = function
        name = function.name
        description = function.description
        self.returnDirectly = returnDirectly
    }

    public func run(input: String) async throws -> String {
        try await function.call(argumentsJsonString: input).botReadableContent
    }
}

