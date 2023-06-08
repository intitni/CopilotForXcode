import Foundation

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

