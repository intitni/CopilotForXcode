import Foundation
import OpenAIService

/// This is a magic function that can do anything with no-code. See
/// https://github.com/Torantulino/AI-Functions for more info.
func callAIFunction(
    function: String,
    args: [Any?],
    description: String
) async throws -> String? {
    let args = args.map { arg -> String in
        if let arg = arg {
            return String(describing: arg)
        } else {
            return "None"
        }
    }
    let argsString = args.joined(separator: ", ")
    let configuration = UserPreferenceChatGPTConfiguration()
        .overriding(.init(temperature: 0))
    let service = LegacyChatGPTService(
        memory: AutoManagedChatGPTMemory(
            systemPrompt: "You are now the following python function: ```# \(description)\n\(function)```\n\nOnly respond with your `return` value.",
            configuration: configuration,
            functionProvider: NoChatGPTFunctionProvider(),
            maxNumberOfMessages: .max
        ),
        configuration: configuration
    )
    return try await service.sendAndWait(content: argsString)
}

