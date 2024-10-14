import ComposableArchitecture
import Foundation
import SuggestionBasic

public enum ModificationAgentResponse {
    case code(String)
    case description(String)
}

public struct ModificationAgentRequest {
    public var code: String
    public var requirement: String
    public var source: ModificationSource
    public var isDetached: Bool
    public var extraSystemPrompt: String?
    public var generateDescriptionRequirement: Bool?
    public var range: CursorRange

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
        generateDescriptionRequirement: Bool? = nil,
        range: CursorRange
    ) {
        self.code = code
        self.requirement = requirement
        self.source = source
        self.isDetached = isDetached
        self.extraSystemPrompt = extraSystemPrompt
        self.generateDescriptionRequirement = generateDescriptionRequirement
        self.range = range
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

public struct ModificationHistoryNode: Equatable {
    public var snippets: IdentifiedArrayOf<ModificationSnippet>
    public var instruction: String

    public init(snippets: IdentifiedArrayOf<ModificationSnippet>, instruction: String) {
        self.snippets = snippets
        self.instruction = instruction
    }
}

