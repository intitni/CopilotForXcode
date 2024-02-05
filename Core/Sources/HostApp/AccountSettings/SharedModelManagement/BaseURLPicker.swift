import ComposableArchitecture
import SwiftUI

struct BaseURLPicker: View {
    let prompt: Text?
    let showIsFullURL: Bool
    let store: StoreOf<BaseURLSelection>
    
    var body: some View {
        WithViewStore(store) { viewStore in
            Group {
                TextField("Base URL", text: viewStore.$baseURL, prompt: prompt)
                    .overlay(alignment: .trailing) {
                        Picker(
                            "",
                            selection: viewStore.$baseURL,
                            content: {
                                if !viewStore.state.availableBaseURLs
                                    .contains(viewStore.state.baseURL),
                                   !viewStore.state.baseURL.isEmpty
                                {
                                    Text("Custom Value").tag(viewStore.state.baseURL)
                                }
                                
                                Text("Empty (Default Value)").tag("")
                                
                                ForEach(viewStore.state.availableBaseURLs, id: \.self) { baseURL in
                                    Text(baseURL).tag(baseURL)
                                }
                            }
                        )
                        .frame(width: 20)
                    }
                if showIsFullURL {
                    Toggle(
                        "Is base URL with full path",
                        isOn: viewStore.$isFullURL
                    )
                    
                    Text(
                        "Add compatibility API's distinct endpoint structure. For example Perplexity.ai API's URL is https://api.perplexity.ai/chat/completions"
                    )
                    .foregroundColor(.secondary)
                    .font(.callout)
                    .dynamicHeightTextInFormWorkaround()
                }
            }
            .onAppear {
                viewStore.send(.appear)
            }
        }
    }
}

