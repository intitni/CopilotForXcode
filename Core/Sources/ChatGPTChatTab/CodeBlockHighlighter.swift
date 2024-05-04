import Foundation
import MarkdownUI
import SharedUIComponents
import SwiftUI

final class CodeBlockHighlighterCacheController {
    private var cache: [String: AttributedString] = [:]
    
    func get(_ key: String) -> AttributedString? {
        cache[key]
    }

    func set(_ key: String, _ value: AttributedString) {
        cache[key] = value
    }
}

struct CodeHighlightCacheEnvironmentKey: EnvironmentKey {
    static var defaultValue: CodeBlockHighlighterCacheController = .init()
}

extension EnvironmentValues {
    var codeHighlightCacheController: CodeBlockHighlighterCacheController {
        get { self[CodeHighlightCacheEnvironmentKey.self] }
        set { self[CodeHighlightCacheEnvironmentKey.self] = newValue }
    }
}

struct ChatCodeSyntaxHighlighter: CodeSyntaxHighlighter {
    let brightMode: Bool
    let font: NSFont
    let colorChange: Color?
    var cacheController: CodeBlockHighlighterCacheController

    init(
        brightMode: Bool,
        font: NSFont,
        colorChange: Color?,
        cacheController: CodeBlockHighlighterCacheController
    ) {
        self.brightMode = brightMode
        self.font = font
        self.colorChange = colorChange
        self.cacheController = cacheController
    }

    func highlightCode(_ code: String, language: String?) -> Text {
        let key = "\(language ?? "unknown") - \(code)"
        if let text = cacheController.get(key) {
            return Text(text)
        }

        let content = highlightedCodeBlock(
            code: code,
            language: language ?? "",
            scenario: "chat",
            brightMode: brightMode,
            font: font
        )
        let string = AttributedString(content)
        Task { @MainActor in
            cacheController.set(key, string)
        }
        return Text(string)
    }
}

