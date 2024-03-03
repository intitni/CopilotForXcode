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

public struct NoChatGPTFunctionArguments: Decodable {}

public protocol ChatGPTFunction {
    typealias NoArguments = NoChatGPTFunctionArguments
    associatedtype Arguments: Decodable
    associatedtype Result: ChatGPTFunctionResult
    typealias ReportProgress = (String) async -> Void

    /// The name of this function.
    /// May contain a-z, A-Z, 0-9, and underscores, with a maximum length of 64 characters.
    var name: String { get }
    /// A short description telling the bot when it should use this function.
    var description: String { get }
    /// The arguments schema that the function take in [JSON schema](https://json-schema.org).
    var argumentSchema: JSONSchemaValue { get }
    /// Prepare to call the function
    func prepare(reportProgress: @escaping ReportProgress) async
    /// Call the function with the given arguments.
    func call(arguments: Arguments, reportProgress: @escaping ReportProgress) async throws
        -> Result
}

public extension ChatGPTFunction {
    /// Call the function with the given arguments in JSON.
    func call(
        argumentsJsonString: String,
        reportProgress: @escaping ReportProgress
    ) async throws -> Result {
        do {
            let arguments = try JSONDecoder()
                .decode(Arguments.self, from: argumentsJsonString.data(using: .utf8) ?? Data())
            return try await call(arguments: arguments, reportProgress: reportProgress)
        } catch {
            await reportProgress("Error: Failed to decode arguments. \(error.localizedDescription)")
            throw error
        }
    }
}

public extension ChatGPTFunction where Arguments == NoArguments {
    var argumentSchema: JSONSchemaValue {
        [.type: "object", .properties: [:]]
    }
}

/// This kind of function is only used to get a structured output from the bot.
public protocol ChatGPTArgumentsCollectingFunction: ChatGPTFunction where Result == String {}

public extension ChatGPTArgumentsCollectingFunction {
    @available(
        *,
        deprecated,
        message: "This function is only used to get a structured output from the bot."
    )
    func prepare(reportProgress: @escaping ReportProgress = { _ in }) async {
        assertionFailure("This function is only used to get a structured output from the bot.")
    }

    @available(
        *,
        deprecated,
        message: "This function is only used to get a structured output from the bot."
    )
    func call(
        arguments: Arguments,
        reportProgress: @escaping ReportProgress = { _ in }
    ) async throws -> Result {
        assertionFailure("This function is only used to get a structured output from the bot.")
        return ""
    }
    
    @available(
        *,
        deprecated,
        message: "This function is only used to get a structured output from the bot."
    )
    func call(
        argumentsJsonString: String,
        reportProgress: @escaping ReportProgress
    ) async throws -> Result {
        assertionFailure("This function is only used to get a structured output from the bot.")
        return ""
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

