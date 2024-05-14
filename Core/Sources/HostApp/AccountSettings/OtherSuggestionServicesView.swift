import Foundation
import SwiftUI

struct OtherSuggestionServicesView: View {
    @Environment(\.openURL) var openURL
    var body: some View {
        VStack(alignment: .leading) {
            Text(
                "You can use other locally run services (Tabby, Ollma, etc.) to generate suggestions with the Custom Suggestion Service extension."
            )
            .lineLimit(nil)
            .multilineTextAlignment(.leading)

            Button(action: {
                if let url = URL(
                    string: "https://github.com/intitni/CustomSuggestionServiceForCopilotForXcode"
                ) {
                    openURL(url)
                }
            }) {
                Text("Get It Now")
            }
        }
    }
}

#Preview {
    OtherSuggestionServicesView()
        .frame(width: 200)
}

