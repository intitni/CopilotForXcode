import Foundation
import MarkdownUI
import SwiftUI

struct ThemedMarkdownText: View {
    @AppStorage(\.syncChatCodeHighlightTheme) var syncCodeHighlightTheme
    @AppStorage(\.codeForegroundColorLight) var codeForegroundColorLight
    @AppStorage(\.codeBackgroundColorLight) var codeBackgroundColorLight
    @AppStorage(\.codeForegroundColorDark) var codeForegroundColorDark
    @AppStorage(\.codeBackgroundColorDark) var codeBackgroundColorDark
    @AppStorage(\.chatFontSize) var chatFontSize
    @AppStorage(\.chatCodeFont) var chatCodeFont
    @Environment(\.colorScheme) var colorScheme

    let content: MarkdownContent

    init(_ text: String) {
        content = .init(text)
    }

    init(_ content: MarkdownContent) {
        self.content = content
    }

    var body: some View {
        Markdown(content)
            .textSelection(.enabled)
            .markdownTheme(.custom(
                fontSize: chatFontSize,
                codeFont: chatCodeFont.value.nsFont,
                codeBlockBackgroundColor: {
                    if syncCodeHighlightTheme {
                        if colorScheme == .light, let color = codeBackgroundColorLight.value {
                            return color.swiftUIColor
                        } else if let color = codeBackgroundColorDark.value {
                            return color.swiftUIColor
                        }
                    }

                    return Color(nsColor: .textBackgroundColor).opacity(0.7)
                }(),
                codeBlockLabelColor: {
                    if syncCodeHighlightTheme {
                        if colorScheme == .light,
                           let color = codeForegroundColorLight.value
                        {
                            return color.swiftUIColor.opacity(0.5)
                        } else if let color = codeForegroundColorDark.value {
                            return color.swiftUIColor.opacity(0.5)
                        }
                    }
                    return Color.secondary.opacity(0.7)
                }()
            ))
    }
}

// MARK: - Theme

extension MarkdownUI.Theme {
    static func custom(
        fontSize: Double,
        codeFont: NSFont,
        codeBlockBackgroundColor: Color,
        codeBlockLabelColor: Color
    ) -> MarkdownUI.Theme {
        .gitHub.text {
            ForegroundColor(.primary)
            BackgroundColor(Color.clear)
            FontSize(fontSize)
        }
        .codeBlock { configuration in
            let wrapCode = UserDefaults.shared.value(for: \.wrapCodeInChatCodeBlock)
                || ["plaintext", "text", "markdown", "sh", "bash", "shell", "latex", "tex"]
                .contains(configuration.language)

            if wrapCode {
                AsyncCodeBlockView(
                    fenceInfo: configuration.language,
                    content: configuration.content,
                    font: codeFont
                )
                .codeBlockLabelStyle()
                .codeBlockStyle(
                    configuration,
                    backgroundColor: codeBlockBackgroundColor,
                    labelColor: codeBlockLabelColor
                )
            } else {
                ScrollView(.horizontal) {
                    AsyncCodeBlockView(
                        fenceInfo: configuration.language,
                        content: configuration.content,
                        font: codeFont
                    )
                    .codeBlockLabelStyle()
                }
                .workaroundForVerticalScrollingBugInMacOS()
                .codeBlockStyle(
                    configuration,
                    backgroundColor: codeBlockBackgroundColor,
                    labelColor: codeBlockLabelColor
                )
            }
        }
    }
}

