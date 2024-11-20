import ChatBasic
import ComposableArchitecture
import Foundation
import SuggestionBasic

public enum ModificationAgentResponse {
    case code(String)
}

public struct ModificationAgentRequest {
    public var code: String
    public var requirement: String
    public var source: ModificationSource
    public var isDetached: Bool
    public var extraSystemPrompt: String?
    public var range: CursorRange
    public var references: [ChatMessage.Reference]
    public var topics: [ChatMessage.Reference]

    public struct ModificationSource: Equatable {
        public var language: CodeLanguage
        public var documentURL: URL
        public var projectRootURL: URL
        public var content: String
        public var lines: [String]

        public init(
            language: CodeLanguage,
            documentURL: URL,
            projectRootURL: URL,
            content: String,
            lines: [String]
        ) {
            self.language = language
            self.documentURL = documentURL
            self.projectRootURL = projectRootURL
            self.content = content
            self.lines = lines
        }
    }

    public init(
        code: String,
        requirement: String,
        source: ModificationSource,
        isDetached: Bool,
        extraSystemPrompt: String? = nil,
        range: CursorRange,
        references: [ChatMessage.Reference],
        topics: [ChatMessage.Reference]
    ) {
        self.code = code
        self.requirement = requirement
        self.source = source
        self.isDetached = isDetached
        self.extraSystemPrompt = extraSystemPrompt
        self.range = range
        self.references = references
        self.topics = topics
    }
}

public protocol ModificationAgent {
    typealias Request = ModificationAgentRequest
    typealias Response = ModificationAgentResponse

    func send(_ request: Request) -> AsyncThrowingStream<Response, any Error>
}

public struct ModificationSnippet: Equatable, Identifiable {
    public let id = UUID()
    public var startLineIndex: Int
    public var originalCode: String
    public var modifiedCode: String
    public var description: String
    public var error: String?
    public var attachedRange: CursorRange

    public init(
        startLineIndex: Int,
        originalCode: String,
        modifiedCode: String,
        description: String,
        error: String?,
        attachedRange: CursorRange
    ) {
        self.startLineIndex = startLineIndex
        self.originalCode = originalCode
        self.modifiedCode = modifiedCode
        self.description = description
        self.error = error
        self.attachedRange = attachedRange
    }
}

public enum ModificationAttachedTarget: Equatable {
    case file(URL, projectURL: URL, code: String, lines: [String])
    case dynamic
}

public struct ModificationHistoryNode {
    public var snippets: IdentifiedArrayOf<ModificationSnippet>
    public var instruction: NSAttributedString

    public init(
        snippets: IdentifiedArrayOf<ModificationSnippet>,
        instruction: NSAttributedString
    ) {
        self.snippets = snippets
        self.instruction = instruction
    }
}

