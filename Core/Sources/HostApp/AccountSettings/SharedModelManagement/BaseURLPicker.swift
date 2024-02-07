import ComposableArchitecture
import SwiftUI

struct BaseURLPicker<TrailingContent: View>: View {
    let title: String
    let prompt: Text?
    let store: StoreOf<BaseURLSelection>
    @ViewBuilder let trailingContent: () -> TrailingContent
    
    var body: some View {
        WithViewStore(store) { viewStore in
            HStack {
                TextField(title, text: viewStore.$baseURL, prompt: prompt)
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
                
                trailingContent()
                    .foregroundStyle(.secondary)
            }
            .onAppear {
                viewStore.send(.appear)
            }
        }
    }
}

extension BaseURLPicker where TrailingContent == EmptyView {
    init(
        title: String,
        prompt: Text? = nil,
        store: StoreOf<BaseURLSelection>
    ) {
        self.init(
            title: title,
            prompt: prompt,
            store: store,
            trailingContent: { EmptyView() }
        )
    }
}
