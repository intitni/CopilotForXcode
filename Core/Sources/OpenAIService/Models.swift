import Foundation

struct Cancellable {
    let cancel: () -> Void
    func callAsFunction() {
        cancel()
    }
}

public struct ChatMessage: Equatable, Codable {
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
