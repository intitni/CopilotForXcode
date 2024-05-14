import AppKit
import struct CopilotForXcodeKit.SuggestionServiceConfiguration
import Foundation
import Preferences
import SuggestionModel
import UserDefaultsObserver

public struct SuggestionRequest {
    public var fileURL: URL
    public var relativePath: String
    public var content: String
    public var lines: [String]
    public var cursorPosition: CursorPosition
    public var cursorOffset: Int
    public var tabSize: Int
    public var indentSize: Int
    public var usesTabsForIndentation: Bool
    public var relevantCodeSnippets: [RelevantCodeSnippet]

    public init(
        fileURL: URL,
        relativePath: String,
        content: String,
        lines: [String],
        cursorPosition: CursorPosition,
        cursorOffset: Int,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool,
        relevantCodeSnippets: [RelevantCodeSnippet]
    ) {
        self.fileURL = fileURL
        self.relativePath = relativePath
        self.content = content
        self.lines = lines
        self.cursorPosition = cursorPosition
        self.cursorOffset = cursorOffset
        self.tabSize = tabSize
        self.indentSize = indentSize
        self.usesTabsForIndentation = usesTabsForIndentation
        self.relevantCodeSnippets = relevantCodeSnippets
    }
}

public struct RelevantCodeSnippet: Codable {
    public var content: String
    public var priority: Int
    public var filePath: String

    public init(content: String, priority: Int, filePath: String) {
        self.content = content
        self.priority = priority
        self.filePath = filePath
    }
}

public protocol SuggestionServiceProvider {
    func getSuggestions(_ request: SuggestionRequest) async throws -> [CodeSuggestion]
    func notifyAccepted(_ suggestion: CodeSuggestion) async
    func notifyRejected(_ suggestions: [CodeSuggestion]) async
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws
    func notifyChangeTextDocument(fileURL: URL, content: String) async throws
    func notifyCloseTextDocument(fileURL: URL) async throws
    func notifySaveTextDocument(fileURL: URL) async throws
    func cancelRequest() async
    func terminate() async

    var configuration: SuggestionServiceConfiguration { get async }
}

public typealias SuggestionServiceConfiguration = CopilotForXcodeKit.SuggestionServiceConfiguration
