import Foundation

public struct ChatGPTMessage: Equatable, Codable {
    public enum Role: String, Codable, Equatable {
        case system
        case user
        case assistant
    }

    public var role: Role
    public var content: String
    public var summary: String?
    public var id: String?

    public init(role: Role, content: String, summary: String? = nil, id: String? = nil) {
        self.role = role
        self.content = content
        self.summary = summary
        self.id = id
    }
}

public enum ChatGPTModel: String {
    case gpt_3_5_turbo = "gpt-3.5-turbo"
    case gpt_3_5_turbo_0301 = "gpt-3.5-turbo-0301"
    case gpt_4_0314 = "gpt-4-0314"
    case gpt_4_32k = "gpt-4-32k"
    case gpt_4_32k_0314 = "gpt-4-32k-0314"
}

/// https://platform.openai.com/docs/api-reference/chat/create
struct ChatGPTRequest: Codable {
    var model: String
    var messages: [ChatGPTMessage]
    var temperature: Double?
    var top_p: Double?
    var n: Double?
    var stream: Bool?
    var stop: [String]?
    var max_tokens: Int?
    var presence_penalty: Double?
    var frequency_penalty: Double?
    var logit_bias: [String: Double]?
    var user: String?
}

/// https://platform.openai.com/docs/api-reference/chat/create
struct ChatGPTResponse: Codable {
    var id: String
    var object: String
    var created: Int
    var choices: [Choice]
    var usage: Usage

    struct Usage: Codable {
        var prompt_tokens: Int
        var completion_tokens: Int
        var total_tokens: Int
    }

    struct Choice: Codable {
        var index: Int
        var message: ChatGPTMessage
        var finish_reason: String
    }
}

struct ChatGPTDataTrunk: Codable {
    var id: String
    var object: String
    var created: Int
    var model: String
    var choices: [Choice]

    struct Choice: Codable {
        var delta: Delta
        var index: Int
        var finish_reason: String?

        struct Delta: Codable {
            var role: ChatGPTMessage.Role?
            var content: String?
        }
    }
}
