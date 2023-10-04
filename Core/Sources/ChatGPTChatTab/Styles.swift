import AppKit
import MarkdownUI
import SharedUIComponents
import SwiftUI

extension Color {
    static var contentBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.isDarkMode {
                return #colorLiteral(red: 0.1580096483, green: 0.1730263829, blue: 0.2026666105, alpha: 1)
            }
            return .white
        }))
    }

    static var userChatContentBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.isDarkMode {
                return #colorLiteral(red: 0.2284317913, green: 0.2145925438, blue: 0.3214019983, alpha: 1)
            }
            return #colorLiteral(red: 0.896820749, green: 0.8709097223, blue: 0.9766687925, alpha: 1)
        }))
    }
}

extension NSAppearance {
    var isDarkMode: Bool {
        if bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
            return true
        } else {
            return false
        }
    }
}

extension View {
    func codeBlockLabelStyle() -> some View {
        self
            .relativeLineSpacing(.em(0.225))
            .markdownTextStyle {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
            }
            .padding(16)
            .padding(.top, 14)
    }
    
    func codeBlockStyle(_ configuration: CodeBlockConfiguration) -> some View {
        self
            .background(Color(nsColor: .textBackgroundColor).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .top) {
                HStack(alignment: .center) {
                    Text(configuration.language ?? "code")
                        .foregroundStyle(.tertiary)
                        .font(.callout)
                        .padding(.leading, 8)
                        .lineLimit(1)
                    Spacer()
                    CopyButton {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(configuration.content, forType: .string)
                    }
                }
            }
            .markdownMargin(top: 4, bottom: 16)
    }
}

extension MarkdownUI.Theme {
    static func custom(fontSize: Double) -> MarkdownUI.Theme {
        .gitHub.text {
            ForegroundColor(.primary)
            BackgroundColor(Color.clear)
            FontSize(fontSize)
        }
        .codeBlock { configuration in
            let wrapCode = UserDefaults.shared.value(for: \.wrapCodeInChatCodeBlock)

            if wrapCode {
                configuration.label
                    .codeBlockLabelStyle()
                    .codeBlockStyle(configuration)
            } else {
                ScrollView(.horizontal) {
                    configuration.label
                        .codeBlockLabelStyle()
                }
                .workaroundForVerticalScrollingBugInMacOS()
                .codeBlockStyle(configuration)
            }
        }
    }

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

final class VerticalScrollingFixHostingView<Content>: NSHostingView<Content> where Content: View {
    override func wantsForwardedScrollEvents(for axis: NSEvent.GestureAxis) -> Bool {
        return axis == .vertical
    }
}

struct VerticalScrollingFixViewRepresentable<Content>: NSViewRepresentable where Content: View {
    let content: Content

    func makeNSView(context: Context) -> NSHostingView<Content> {
        return VerticalScrollingFixHostingView<Content>(rootView: content)
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {}
}

struct VerticalScrollingFixWrapper<Content>: View where Content: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VerticalScrollingFixViewRepresentable(content: self.content())
    }
}

extension View {
    /// https://stackoverflow.com/questions/64920744/swiftui-nested-scrollviews-problem-on-macos
    @ViewBuilder func workaroundForVerticalScrollingBugInMacOS() -> some View {
        VerticalScrollingFixWrapper { self }
    }
}

