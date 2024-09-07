import Preferences
import SwiftUI

public struct CodeBlock: View {
    public let code: String
    public let language: String
    public let startLineIndex: Int
    public let scenario: String
    public let colorScheme: ColorScheme
    public let commonPrecedingSpaceCount: Int
    public let highlightedCode: [NSAttributedString]
    public let firstLinePrecedingSpaceCount: Int
    public let font: NSFont
    public let droppingLeadingSpaces: Bool
    public let proposedForegroundColor: Color?
    public let wrapCode: Bool

    public init(
        code: String,
        language: String,
        startLineIndex: Int,
        scenario: String,
        colorScheme: ColorScheme,
        firstLinePrecedingSpaceCount: Int = 0,
        font: NSFont,
        droppingLeadingSpaces: Bool,
        proposedForegroundColor: Color?,
        wrapCode: Bool = true
    ) {
        self.code = code
        self.language = language
        self.startLineIndex = startLineIndex
        self.scenario = scenario
        self.colorScheme = colorScheme
        self.droppingLeadingSpaces = droppingLeadingSpaces
        self.firstLinePrecedingSpaceCount = firstLinePrecedingSpaceCount
        self.font = font
        self.proposedForegroundColor = proposedForegroundColor
        self.wrapCode = wrapCode
        let padding = firstLinePrecedingSpaceCount > 0
            ? String(repeating: " ", count: firstLinePrecedingSpaceCount)
            : ""
        let result = Self.highlight(
            code: padding + code,
            language: language,
            scenario: scenario,
            colorScheme: colorScheme,
            font: font,
            droppingLeadingSpaces: droppingLeadingSpaces
        )
        commonPrecedingSpaceCount = result.commonLeadingSpaceCount
        highlightedCode = result.code
    }
    
    var foregroundColor: Color {
        proposedForegroundColor ?? (colorScheme == .dark ? .white : .black)
    }

    public var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<highlightedCode.endIndex, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(index + startLineIndex + 1)")
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(foregroundColor.opacity(0.5))
                        .frame(minWidth: 40)
                    Text(AttributedString(highlightedCode[index]))
                        .foregroundColor(foregroundColor.opacity(0.3))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .overlay(alignment: .topLeading) {
                            if index == 0, commonPrecedingSpaceCount > 0 {
                                Text("\(commonPrecedingSpaceCount + 1)")
                                    .padding(.top, -12)
                                    .font(.footnote)
                                    .foregroundStyle(foregroundColor)
                                    .opacity(0.3)
                            }
                        }
                }
            }
        }
        .foregroundColor(.white)
        .font(.init(font))
        .padding(.leading, 4)
        .padding(.trailing)
        .padding(.top, commonPrecedingSpaceCount > 0 ? 16 : 4)
        .padding(.bottom, 4)
    }

    static func highlight(
        code: String,
        language: String,
        scenario: String,
        colorScheme: ColorScheme,
        font: NSFont,
        droppingLeadingSpaces: Bool
    ) -> (code: [NSAttributedString], commonLeadingSpaceCount: Int) {
        return CodeHighlighting.highlighted(
            code: code,
            language: language,
            scenario: scenario,
            brightMode: colorScheme != .dark,
            droppingLeadingSpaces: droppingLeadingSpaces,
            font: font
        )
    }
}

// MARK: - Preview

struct CodeBlock_Previews: PreviewProvider {
    static var previews: some View {
        CodeBlock(
            code: """
            let foo = Foo()
            let bar = Bar()
            """,
            language: "swift",
            startLineIndex: 0,
            scenario: "",
            colorScheme: .dark,
            firstLinePrecedingSpaceCount: 0,
            font: .monospacedSystemFont(ofSize: 12, weight: .regular),
            droppingLeadingSpaces: true,
            proposedForegroundColor: nil
        )
    }
}

