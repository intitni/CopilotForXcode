import ComposableArchitecture
import SwiftUI

struct APIKeyPicker: View {
    let store: StoreOf<APIKeySelection>

    var body: some View {
        WithViewStore(store) { viewStore in
            HStack {
                Picker(
                    selection: viewStore.$apiKeyName,
                    content: {
                        Text("No API Key").tag("")
                        if viewStore.state.availableAPIKeyNames.isEmpty {
                            Text("No API key found, please add a new one →")
                        }
                        
                        if !viewStore.state.availableAPIKeyNames.contains(viewStore.state.apiKeyName),
                           !viewStore.state.apiKeyName.isEmpty {
                            Text("Key not found: \(viewStore.state.apiKeyName)")
                                .tag(viewStore.state.apiKeyName)
                        }
                        
                        ForEach(viewStore.state.availableAPIKeyNames, id: \.self) { name in
                            Text(name).tag(name)
                        }

                    },
                    label: { Text("API Key") }
                )

                Button(action: { store.send(.manageAPIKeysButtonClicked) }) {
                    Text(Image(systemName: "key"))
                }
            }.sheet(isPresented: viewStore.$isAPIKeyManagementPresented) {
                APIKeyManagementView(store: store.scope(
                    state: \.apiKeyManagement,
                    action: APIKeySelection.Action.apiKeyManagement
                ))
            }
        }
        .onAppear {
            store.send(.appear)
        }
    }
}

