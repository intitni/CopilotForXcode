import Foundation
import MarkdownUI
import SwiftUI

extension MarkdownUI.Theme {
    static func functionCall(fontSize: Double) -> MarkdownUI.Theme {
        .gitHub.text {
            ForegroundColor(.secondary)
            BackgroundColor(Color.clear)
            FontSize(fontSize - 1)
        }
        .list { configuration in
            configuration.label
                .markdownMargin(top: 4, bottom: 4)
        }
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: 0, bottom: 4)
        }
        .codeBlock { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.225))
                .markdownTextStyle {
                    FontFamilyVariant(.monospaced)
                    FontSize(.em(0.85))
                }
                .padding(16)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .markdownMargin(top: 4, bottom: 4)
        }
    }
}
