import AppKit
import struct CopilotForXcodeKit.SuggestionServiceConfiguration
import struct CopilotForXcodeKit.WorkspaceInfo
import Foundation
import Preferences
import SuggestionBasic
import UserDefaultsObserver

public struct SuggestionRequest {
    public var fileURL: URL
    public var relativePath: String
    public var content: String
    public var originalContent: String
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
        originalContent: String,
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
        self.originalContent = content
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
    func getSuggestions(
        _ request: SuggestionRequest,
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async throws -> [CodeSuggestion]
    func notifyAccepted(
        _ suggestion: CodeSuggestion,
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async
    func notifyRejected(
        _ suggestions: [CodeSuggestion],
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async
    func cancelRequest(workspaceInfo: CopilotForXcodeKit.WorkspaceInfo) async

    var configuration: SuggestionServiceConfiguration { get async }
}

public typealias SuggestionServiceConfiguration = CopilotForXcodeKit.SuggestionServiceConfiguration
