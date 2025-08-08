import AppKit
import Client
import OpenAIService
import Preferences
import SuggestionBasic
import SwiftUI

final class BingSearchViewSettings: ObservableObject {
    @AppStorage(\.bingSearchSubscriptionKey) var bingSearchSubscriptionKey: String
    @AppStorage(\.bingSearchEndpoint) var bingSearchEndpoint: String
    init() {}
}

struct BingSearchView: View {
    @Environment(\.openURL) var openURL
    @StateObject var settings = BingSearchViewSettings()

    var body: some View {
        Form {
            Button(action: {
                let url = URL(string: "https://www.microsoft.com/bing/apis/bing-web-search-api")!
                openURL(url)
            }) {
                Text("Apply for Subscription Key for Free")
            }
            
            SecureField(text: $settings.bingSearchSubscriptionKey, prompt: Text("")) {
                Text("Bing Search Subscription Key")
            }
            .textFieldStyle(.roundedBorder)

            TextField(
                text: $settings.bingSearchEndpoint,
                prompt: Text("https://api.bing.microsoft.com/***")
            ) {
                Text("Bing Search Endpoint")
            }.textFieldStyle(.roundedBorder)
        }
    }
}

struct BingSearchView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            BingSearchView()
        }
        .frame(height: 800)
        .padding(.all, 8)
    }
}

