import SwiftUI
import ComposableArchitecture

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
                            ForEach(viewStore.state.availableBaseURLs, id: \.self) { baseURL in
                                Text(baseURL).tag(baseURL)
                            }
                        }
                    )
                    .frame(width: 20)
                }
        }
    }
}
