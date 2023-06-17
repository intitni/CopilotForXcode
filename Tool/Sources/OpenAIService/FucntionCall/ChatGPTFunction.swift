import Foundation

public enum ChatGPTFunctionCallPhase {
    case detected
    case processing(argumentsJsonString: String)
    case ended(argumentsJsonString: String, result: String)
    case error(argumentsJsonString: String, result: Error)
}

public protocol ChatGPTFunction {
    associatedtype Arguments: Decodable

    /// The name of the function.
    var name: String { get }
    /// The arguments schema that the function take in [JSON schema](https://json-schema.org).
    var argumentsSchema: String { get }
    /// Call the function with the given arguments.
    func call(arguments: Arguments) async throws -> String
    /// The message to present in different phases.
    func message(at phase: ChatGPTFunctionCallPhase) -> String
}

public extension ChatGPTFunction {
    /// Call the function with the given arguments in JSON.
    func call(argumentsJsonString: String) async throws -> String {
        let arguments = try JSONDecoder()
            .decode(Arguments.self, from: argumentsJsonString.data(using: .utf8) ?? Data())
        return try await call(arguments: arguments)
    }
}

