import Foundation
import MarkdownUI
import SwiftUI

struct FunctionMessage: View {
    let id: String
    let text: String
    @AppStorage(\.chatFontSize) var chatFontSize

    var body: some View {
        Markdown(text)
            .textSelection(.enabled)
            .markdownTheme(.functionCall(fontSize: chatFontSize))
            .padding(.vertical, 2)
            .padding(.trailing, 2)
    }
}

#Preview {
    FunctionMessage(id: "1", text: """
    Searching for something...
    - abc
    - [def](https://1.com)
    > hello
    > hi
    """)
    .padding()
    .fixedSize()
}

