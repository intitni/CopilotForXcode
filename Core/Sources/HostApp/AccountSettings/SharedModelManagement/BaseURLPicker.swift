import ComposableArchitecture
import SwiftUI

struct BaseURLPicker: View {
    let prompt: Text?
    let store: StoreOf<BaseURLSelection>

    var body: some View {
        WithViewStore(store) { viewStore in
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
                .onAppear {
                    viewStore.send(.appear)
                }
        }
    }
}

