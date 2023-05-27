import SwiftUI

struct CodeBlock: View {
    let code: String
    let language: String
    let startLineIndex: Int
    let colorScheme: ColorScheme
    let commonPrecedingSpaceCount: Int
    let highlightedCode: [NSAttributedString]
    let firstLinePrecedingSpaceCount: Int
    let fontSize: Double

    @AppStorage(\.disableLazyVStack) var disableLazyVStack

    init(
        code: String,
        language: String,
        startLineIndex: Int,
        colorScheme: ColorScheme,
        firstLinePrecedingSpaceCount: Int = 0,
        fontSize: Double
    ) {
        self.code = code
        self.language = language
        self.startLineIndex = startLineIndex
        self.colorScheme = colorScheme
        self.firstLinePrecedingSpaceCount = firstLinePrecedingSpaceCount
        self.fontSize = fontSize
        let padding = firstLinePrecedingSpaceCount > 0
            ? String(repeating: " ", count: firstLinePrecedingSpaceCount)
            : ""
        let result = Self.highlight(
            code: padding + code,
            language: language,
            colorScheme: colorScheme,
            fontSize: fontSize
        )
        commonPrecedingSpaceCount = result.commonLeadingSpaceCount
        highlightedCode = result.code
    }

    @ViewBuilder
    func vstack(@ViewBuilder content: () -> some View) -> some View {
        if disableLazyVStack {
            VStack(spacing: 2) {
                content()
            }
        } else {
            LazyVStack(spacing: 2) {
                content()
            }
        }
    }

    var body: some View {
        vstack {
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
        .font(.system(size: fontSize, design: .monospaced))
        .padding(.leading, 4)
        .padding([.trailing, .top, .bottom])
    }

    static func highlight(
        code: String,
        language: String,
        colorScheme: ColorScheme,
        fontSize: Double
    ) -> (code: [NSAttributedString], commonLeadingSpaceCount: Int) {
        return highlighted(
            code: code,
            language: language,
            brightMode: colorScheme != .dark,
            droppingLeadingSpaces: UserDefaults.shared
                .value(for: \.hideCommonPrecedingSpacesInSuggestion),
            fontSize: fontSize
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
            colorScheme: .dark,
            firstLinePrecedingSpaceCount: 0,
            fontSize: 12
        )
    }
}

