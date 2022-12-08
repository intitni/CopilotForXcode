import CopilotModel
import Foundation

public struct EditorContent: Codable {
    public init(content: String, lines: [String], uti: String, cursorPosition: CursorPosition, tabSize: Int, indentSize: Int, usesTabsForIndentation: Bool) {
        self.content = content
        self.lines = lines
        self.uti = uti
        self.cursorPosition = cursorPosition
        self.tabSize = tabSize
        self.indentSize = indentSize
        self.usesTabsForIndentation = usesTabsForIndentation
    }

    public var content: String
    public var lines: [String]
    public var uti: String
    public var cursorPosition: CursorPosition
    public var tabSize: Int
    public var indentSize: Int
    public var usesTabsForIndentation: Bool
}

public struct UpdatedContent: Codable {
    public init(content: String, newCursor: CursorPosition? = nil, modifications: [Modification]) {
        self.content = content
        self.newCursor = newCursor
        self.modifications = modifications
    }

    public var content: String
    public var newCursor: CursorPosition?
    public var modifications: [Modification]
}
