import Dependencies
import Foundation
import SuggestionBasic

public struct PromptToCodeSource {
    public var language: CodeLanguage
    public var documentURL: URL
    public var projectRootURL: URL
    public var content: String
    public var lines: [String]
    public var range: CursorRange

    public init(
        language: CodeLanguage,
        documentURL: URL,
        projectRootURL: URL,
        content: String,
        lines: [String],
        range: CursorRange
    ) {
        self.language = language
        self.documentURL = documentURL
        self.projectRootURL = projectRootURL
        self.content = content
        self.lines = lines
        self.range = range
    }
}
