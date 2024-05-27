import ComposableArchitecture
import SwiftUI

struct BaseURLPicker<TrailingContent: View>: View {
    let title: String
    let prompt: Text?
    @Perception.Bindable var store: StoreOf<BaseURLSelection>
    @ViewBuilder let trailingContent: () -> TrailingContent

    var body: some View {
        WithPerceptionTracking {
            HStack {
                TextField(title, text: $store.baseURL, prompt: prompt)
                    .overlay(alignment: .trailing) {
                        Picker(
                            "",
                            selection: $store.baseURL,
                            content: {
                                if !store.availableBaseURLs
                                    .contains(store.baseURL),
                                    !store.baseURL.isEmpty
                                {
                                    Text("Custom Value").tag(store.baseURL)
                                }

                                Text("Empty (Default Value)").tag("")

                                ForEach(store.availableBaseURLs, id: \.self) { baseURL in
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
                store.send(.appear)
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

