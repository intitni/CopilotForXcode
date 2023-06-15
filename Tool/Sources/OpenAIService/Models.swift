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
    public var content: String {
        didSet {
            tokensCount = nil
        }
    }
    public var summary: String?
    public var id: String
    public var tokensCount: Int?

    public init(
        id: String = UUID().uuidString,
        role: Role,
        content: String,
        summary: String? = nil,
        tokenCount: Int? = nil
    ) {
        self.role = role
        self.content = content
        self.summary = summary
        self.id = id
        self.tokensCount = tokenCount
    }
}
