import ComposableArchitecture
import SwiftUI

struct BaseURLPicker: View {
    let prompt: Text?
    let showIsFullURL: Bool
    let store: StoreOf<BaseURLSelection>
    
    var body: some View {
        WithViewStore(store) { viewStore in
            Group {
                if showIsFullURL {
                    Picker(
                        selection: viewStore.$isFullURL,
                        content: {
                            Text("Base URL").tag(false)
                            Text("Full URL").tag(true)
                        },
                        label: { Text("URL") }
                    )
                    .pickerStyle(.segmented)
                }
                HStack {
                    TextField(
                        showIsFullURL ? "" : "Base URL",
                        text: viewStore.$baseURL,
                        prompt: prompt
                    )
                    if viewStore.isFullURL == false {
                        Text("/v1/chat/completions")
                    }
                }
                .padding(.trailing)
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
            }
            .onAppear {
                viewStore.send(.appear)
            }
        }
    }
}

