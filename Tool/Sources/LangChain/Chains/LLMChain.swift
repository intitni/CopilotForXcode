import Foundation

public class ChatModelChain<Input>: Chain {
    public typealias Output = ChatMessage

    var chatModel: ChatModel
    var promptTemplate: (Input) -> [ChatMessage]
    var stops: [String]

    public init(
        chatModel: ChatModel,
        stops: [String] = [],
        promptTemplate: @escaping (Input) -> [ChatMessage]
    ) {
        self.chatModel = chatModel
        self.promptTemplate = promptTemplate
        self.stops = stops
    }

    public func callLogic(
        _ input: Input,
        callbackManagers: [CallbackManager]
    ) async throws -> Output {
        let prompt = promptTemplate(input)
        let output = try await chatModel.generate(
            prompt: prompt,
            stops: stops,
            callbackManagers: callbackManagers
        )
        return output
    }

    public func parseOutput(_ output: Output) -> String {
        if let content = output.content {
            return content
        } else if let functionCall = output.functionCall {
            return "\(functionCall.name): \(functionCall.arguments)"
        }
        
        return ""
    }
}

