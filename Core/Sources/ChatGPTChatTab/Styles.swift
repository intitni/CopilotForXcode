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

    func codeBlockStyle(
        _ configuration: CodeBlockConfiguration,
        backgroundColor: Color,
        labelColor: Color
    ) -> some View {
        background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .top) {
                HStack(alignment: .center) {
                    Text(configuration.language ?? "code")
                        .foregroundStyle(labelColor)
                        .font(.callout.bold())
                        .padding(.leading, 8)
                        .lineLimit(1)
                    Spacer()
                    CopyButton {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(configuration.content, forType: .string)
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.05), lineWidth: 1)
            }
            .markdownMargin(top: 4, bottom: 16)
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

