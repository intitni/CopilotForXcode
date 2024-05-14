import Foundation
import MarkdownUI
import SwiftUI

extension MarkdownUI.Theme {
    static func instruction(fontSize: Double) -> MarkdownUI.Theme {
        .gitHub.text {
            ForegroundColor(.primary)
            BackgroundColor(Color.clear)
            FontSize(fontSize)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
            BackgroundColor(Color.secondary.opacity(0.2))
        }
        .codeBlock { configuration in
            let wrapCode = UserDefaults.shared.value(for: \.wrapCodeInChatCodeBlock)

            if wrapCode {
                configuration.label
                    .codeBlockLabelStyle()
                    .codeBlockStyle(
                        configuration,
                        backgroundColor: Color(nsColor: .textBackgroundColor).opacity(0.7),
                        labelColor: Color.secondary.opacity(0.7)
                    )
            } else {
                ScrollView(.horizontal) {
                    configuration.label
                        .codeBlockLabelStyle()
                }
                .workaroundForVerticalScrollingBugInMacOS()
                .codeBlockStyle(
                    configuration,
                    backgroundColor: Color(nsColor: .textBackgroundColor).opacity(0.7),
                    labelColor: Color.secondary.opacity(0.7)
                )
            }
        }
        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .markdownTableBorderStyle(.init(
                    color: .init(nsColor: .separatorColor),
                    strokeStyle: .init(lineWidth: 1)
                ))
                .markdownTableBackgroundStyle(
                    .alternatingRows(Color.secondary.opacity(0.1), Color.secondary.opacity(0.2))
                )
                .markdownMargin(top: 0, bottom: 16)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    if configuration.row == 0 {
                        FontWeight(.semibold)
                    }
                    BackgroundColor(nil)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
                .padding(.horizontal, 13)
                .relativeLineSpacing(.em(0.25))
        }
    }
}

