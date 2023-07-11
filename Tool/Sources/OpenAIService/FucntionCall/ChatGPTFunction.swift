import Foundation

public enum ChatGPTFunctionCallPhase {
    case detected
    case processing(argumentsJsonString: String)
    case ended(argumentsJsonString: String, result: ChatGPTFunctionResult)
    case error(argumentsJsonString: String, result: Error)
}

public protocol ChatGPTFunctionResult {
    var botReadableContent: String { get }
}

extension String: ChatGPTFunctionResult {
    public var botReadableContent: String { self }
}

public protocol ChatGPTFunction {
    associatedtype Arguments: Decodable
    associatedtype Result: ChatGPTFunctionResult

    /// The name of this function.
    /// May contain a-z, A-Z, 0-9, and underscores, with a maximum length of 64 characters.
    var name: String { get }
    /// A short description telling the bot when it should use this function.
    var description: String { get }
    /// The arguments schema that the function take in [JSON schema](https://json-schema.org).
    var argumentSchema: JSONSchemaValue { get }
    /// Prepare to call the function
    func prepare() async
    /// Call the function with the given arguments.
    func call(arguments: Arguments) async throws -> Result
    /// The message to present in different phases.
    var reportProgress: (String) async -> Void { get set }
}

public extension ChatGPTFunction {
    /// Call the function with the given arguments in JSON.
    func call(argumentsJsonString: String) async throws -> Result {
        let arguments = try JSONDecoder()
            .decode(Arguments.self, from: argumentsJsonString.data(using: .utf8) ?? Data())
        return try await call(arguments: arguments)
    }
}

struct ChatGPTFunctionSchema: Codable, Equatable {
    var name: String
    var description: String
    var parameters: JSONSchemaValue

    init(name: String, description: String, parameters: JSONSchemaValue) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

