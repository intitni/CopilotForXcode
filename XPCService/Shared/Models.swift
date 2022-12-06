import CopilotModel
import Foundation

struct EditorContent: Codable {
    var content: String
    var lines: [String]
    var uti: String
    var cursorPosition: CursorPosition
    var tabSize: Int
    var indentSize: Int
    var usesTabsForIndentation: Bool
}

struct UpdatedContent: Codable {
    var content: String
    var newCursor: CursorPosition?
}
