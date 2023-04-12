import SwiftUI

struct CodeBlock: View {
    let code: String
    let language: String
    let startLineIndex: Int
    let colorScheme: ColorScheme
    let commonPrecedingSpaceCount: Int
    let highlightedCode: [NSAttributedString]

    init(code: String, language: String, startLineIndex: Int, colorScheme: ColorScheme) {
        self.code = code
        self.language = language
        self.startLineIndex = startLineIndex
        self.colorScheme = colorScheme
        let result = Self.highlight(
            code: code,
            language: language,
            colorScheme: colorScheme
        )
        self.commonPrecedingSpaceCount = result.commonLeadingSpaceCount
        self.highlightedCode = result.code
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<highlightedCode.endIndex, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(index + startLineIndex + 1)")
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 40)
                    Text(AttributedString(highlightedCode[index]))
                        .foregroundColor(.white.opacity(0.1))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(4)
                        .overlay(alignment: .topLeading) {
                            if index == 0, commonPrecedingSpaceCount > 0 {
                                Text("\(commonPrecedingSpaceCount + 1)")
                                    .padding(.top, -12)
                                    .font(.footnote)
                                    .foregroundStyle(colorScheme == .dark ? .white : .black)
                                    .opacity(0.3)
                            }
                        }
                }
            }
        }
        .foregroundColor(.white)
        .font(.system(size: 12, design: .monospaced))
        .padding(.leading, 4)
        .padding([.trailing, .top, .bottom])
    }

    static func highlight(
        code: String,
        language: String,
        colorScheme: ColorScheme
    ) -> (code: [NSAttributedString], commonLeadingSpaceCount: Int) {
        return highlighted(
            code: code,
            language: language,
            brightMode: colorScheme != .dark,
            droppingLeadingSpaces: UserDefaults.shared
                .value(for: \.hideCommonPrecedingSpacesInSuggestion)
        )
    }
}
