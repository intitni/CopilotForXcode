import ChatBasic
import Foundation
import Logger
import TokenEncoder

extension AutoManagedChatGPTMemory {
    struct OpenAIStrategy: AutoManagedChatGPTMemoryStrategy {
        static let encoder: TokenEncoder = TiktokenCl100kBaseTokenEncoder()

        func countToken(_ message: ChatMessage) async -> Int {
            await Self.encoder.countToken(message)
        }
        
        func countToken<F>(_ function: F) async -> Int where F : ChatGPTFunction {
            async let nameTokenCount = Self.encoder.countToken(text: function.name)
            async let descriptionTokenCount = Self.encoder.countToken(text: function.description)
            async let schemaTokenCount = {
                guard let data = try? JSONEncoder().encode(function.argumentSchema),
                      let string = String(data: data, encoding: .utf8)
                else { return 0 }
                return await Self.encoder.countToken(text: string)
            }()

            return await (nameTokenCount + descriptionTokenCount + schemaTokenCount)
        }
    }
}

extension TokenEncoder {
    /// https://github.com/openai/openai-cookbook/blob/main/examples/How_to_count_tokens_with_tiktoken.ipynb
    func countToken(_ message: ChatMessage) async -> Int {
        var total = 3
        var encodingContent = [String]()
        if let content = message.content {
            encodingContent.append(content)
        }
        if let name = message.name {
            encodingContent.append(name)
            total += 1
        }
        if let toolCalls = message.toolCalls {
            for toolCall in toolCalls {
                encodingContent.append(toolCall.id)
                encodingContent.append(toolCall.type)
                encodingContent.append(toolCall.function.name)
                encodingContent.append(toolCall.function.arguments)
                total += 4
                encodingContent.append(toolCall.response.content)
                encodingContent.append(toolCall.id)
            }
        }
        total += await withTaskGroup(of: Int.self, body: { group in
            for content in encodingContent {
                group.addTask {
                    await encode(text: content).count
                }
            }
            return await group.reduce(0, +)
        })
        return total
    }

    func countToken(_ message: inout ChatMessage) async -> Int {
        if let count = message.tokensCount { return count }
        let count = await countToken(message)
        message.tokensCount = count
        return count
    }
}

