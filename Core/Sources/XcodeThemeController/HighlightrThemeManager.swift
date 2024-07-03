import Foundation
import Highlightr
import Preferences

public class HighlightrThemeManager: ThemeManager {
    let defaultManager: ThemeManager

    weak var controller: XcodeThemeController?

    public init(defaultManager: ThemeManager, controller: XcodeThemeController) {
        self.defaultManager = defaultManager
        self.controller = controller
    }

    public func theme(for name: String) -> Theme? {
        let syncSuggestionTheme = UserDefaults.shared.value(for: \.syncSuggestionHighlightTheme)
        let syncPromptToCodeTheme = UserDefaults.shared.value(for: \.syncPromptToCodeHighlightTheme)
        let syncChatTheme = UserDefaults.shared.value(for: \.syncChatCodeHighlightTheme)
        
        lazy var defaultLight = Theme(themeString: defaultLightTheme)
        lazy var defaultDark = Theme(themeString: defaultDarkTheme)

        switch name {
        case "suggestion-light":
            guard syncSuggestionTheme, let theme = theme(lightMode: true) else {
                return defaultLight
            }
            return theme
        case "suggestion-dark":
            guard syncSuggestionTheme, let theme = theme(lightMode: false) else {
                return defaultDark
            }
            return theme
        case "promptToCode-light":
            guard syncPromptToCodeTheme, let theme = theme(lightMode: true) else {
                return defaultLight
            }
            return theme
        case "promptToCode-dark":
            guard syncPromptToCodeTheme, let theme = theme(lightMode: false) else {
                return defaultDark
            }
            return theme
        case "chat-light":
            guard syncChatTheme, let theme = theme(lightMode: true) else {
                return defaultLight
            }
            return theme
        case "chat-dark":
            guard syncChatTheme, let theme = theme(lightMode: false) else {
                return defaultDark
            }
            return theme
        case "light":
            return defaultLight
        case "dark":
            return defaultDark
        default:
            return defaultLight
        }
    }

    func theme(lightMode: Bool) -> Theme? {
        guard let controller else { return nil }
        guard let directories = controller.createSupportDirectoriesIfNeeded() else { return nil }

        let themeURL: URL = if lightMode {
            directories.themeDirectory.appendingPathComponent("highlightjs-light")
        } else {
            directories.themeDirectory.appendingPathComponent("highlightjs-dark")
        }

        if let themeString = try? String(contentsOf: themeURL) {
            return Theme(themeString: themeString)
        }

        controller.syncXcodeThemeIfNeeded()

        if let themeString = try? String(contentsOf: themeURL) {
            return Theme(themeString: themeString)
        }

        return nil
    }
}

let defaultLightTheme = ".hljs{display:block;overflow-x:auto;padding:0.5em;background:#FFFFFFFF;color:#000000D8}.xml .hljs-meta{color:#495460FF}.hljs-comment,.hljs-quote{color:#5D6B79FF}.hljs-tag,.hljs-keyword,.hljs-selector-tag,.hljs-literal,.hljs-name{color:#9A2393FF}.hljs-attribute{color:#805E03FF}.hljs-variable,.hljs-template-variable{color:#6B36A9FF}.hljs-code,.hljs-string,.hljs-meta-string{color:#C31A15FF}.hljs-regexp{color:#000000D8}.hljs-link{color:#0E0EFFFF}.hljs-title{color:#000000FF}.hljs-symbol,.hljs-bullet{color:#805E03FF}.hljs-number{color:#1C00CFFF}.hljs-section{color:#495460FF}.hljs-meta{color:#9A2393FF}.hljs-type,.hljs-built_in,.hljs-builtin-name{color:#3900A0FF}.hljs-class .hljs-title,.hljs-title .class_{color:#0B4F79FF}.hljs-function .hljs-title,.hljs-title .function_{color:#0E67A0FF}.hljs-params{color:#0E67A0FF}.hljs-attr{color:#805E03FF}.hljs-subst{color:#000000D8}.hljs-formula{background-color:#A3CCFEFF;font-style:italic}.hljs-addition{background-color:#baeeba}.hljs-deletion{background-color:#ffc8bd}.hljs-selector-id,.hljs-selector-class{color:#000000D8}.hljs-doctag,.hljs-strong{font-weight:bold}.hljs-emphasis{font-style:italic}"

let defaultDarkTheme = ".hljs{display:block;overflow-x:auto;padding:0.5em;background:#1F1F23FF;color:#FFFFFFD8}.xml .hljs-meta{color:#91A1B1FF}.hljs-comment,.hljs-quote{color:#6B7985FF}.hljs-tag,.hljs-keyword,.hljs-selector-tag,.hljs-literal,.hljs-name{color:#FC5FA2FF}.hljs-attribute{color:#BF8554FF}.hljs-variable,.hljs-template-variable{color:#A166E5FF}.hljs-code,.hljs-string,.hljs-meta-string{color:#FC695DFF}.hljs-regexp{color:#FFFFFFD8}.hljs-link{color:#5482FEFF}.hljs-title{color:#FFFFFFFF}.hljs-symbol,.hljs-bullet{color:#BF8554FF}.hljs-number{color:#CFBF69FF}.hljs-section{color:#91A1B1FF}.hljs-meta{color:#FC5FA2FF}.hljs-type,.hljs-built_in,.hljs-builtin-name{color:#D0A7FEFF}.hljs-class .hljs-title,.hljs-title .class_{color:#5CD7FEFF}.hljs-function .hljs-title,.hljs-title .function_{color:#41A1BFFF}.hljs-params{color:#41A1BFFF}.hljs-attr{color:#BF8554FF}.hljs-subst{color:#FFFFFFD8}.hljs-formula{background-color:#505A6FFF;font-style:italic}.hljs-addition{background-color:#baeeba}.hljs-deletion{background-color:#ffc8bd}.hljs-selector-id,.hljs-selector-class{color:#FFFFFFD8}.hljs-doctag,.hljs-strong{font-weight:bold}.hljs-emphasis{font-style:italic}"
