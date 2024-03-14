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
            return #colorLiteral(red: 0.9896564803, green: 0.9896564803, blue: 0.9896564803, alpha: 1)
        }))
    }

    static var userChatContentBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.isDarkMode {
                return #colorLiteral(red: 0.2284317913, green: 0.2145925438, blue: 0.3214019983, alpha: 1)
            }
            return #colorLiteral(red: 0.9458052187, green: 0.9311983998, blue: 0.9906365955, alpha: 1)
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
    var messageBubbleCornerRadius: Double { 8 }

    func codeBlockLabelStyle() -> some View {
        relativeLineSpacing(.em(0.225))
            .markdownTextStyle {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
            }
            .padding(16)
            .padding(.top, 14)
    }

    func codeBlockStyle(_ configuration: CodeBlockConfiguration) -> some View {
        background(Color(nsColor: .textBackgroundColor).opacity(0.7))
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

struct RoundedCorners: Shape {
    var tl: CGFloat = 0.0
    var tr: CGFloat = 0.0
    var bl: CGFloat = 0.0
    var br: CGFloat = 0.0

    func path(in rect: CGRect) -> Path {
        Path { path in

            let w = rect.size.width
            let h = rect.size.height

            // Make sure we do not exceed the size of the rectangle
            let tr = min(min(self.tr, h / 2), w / 2)
            let tl = min(min(self.tl, h / 2), w / 2)
            let bl = min(min(self.bl, h / 2), w / 2)
            let br = min(min(self.br, h / 2), w / 2)

            path.move(to: CGPoint(x: w / 2.0, y: 0))
            path.addLine(to: CGPoint(x: w - tr, y: 0))
            path.addArc(
                center: CGPoint(x: w - tr, y: tr),
                radius: tr,
                startAngle: Angle(degrees: -90),
                endAngle: Angle(degrees: 0),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: w, y: h - br))
            path.addArc(
                center: CGPoint(x: w - br, y: h - br),
                radius: br,
                startAngle: Angle(degrees: 0),
                endAngle: Angle(degrees: 90),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: bl, y: h))
            path.addArc(
                center: CGPoint(x: bl, y: h - bl),
                radius: bl,
                startAngle: Angle(degrees: 90),
                endAngle: Angle(degrees: 180),
                clockwise: false
            )
            path.addLine(to: CGPoint(x: 0, y: tl))
            path.addArc(
                center: CGPoint(x: tl, y: tl),
                radius: tl,
                startAngle: Angle(degrees: 180),
                endAngle: Angle(degrees: 270),
                clockwise: false
            )
            path.closeSubpath()
        }
    }
}

