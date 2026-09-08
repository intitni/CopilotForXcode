import AIModel
import ComposableArchitecture
import SwiftUI

@MainActor
struct TabbyModelEditView: View {
    @Perception.Bindable var store: StoreOf<TabbyModelEdit>

    @Environment(\.dismiss) var dismiss

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(spacing: 0) {
                    Form {
                        form
                    }
                    .padding()

                    Divider()

                    HStack {
                        Spacer()

                        Button("Cancel") {
                            dismiss()
                        }
                        .keyboardShortcut(.cancelAction)

                        Button(action: {
                            store.send(.saveButtonClicked)
                        }) {
                            Text("Save")
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                    .padding()
                }
            }
            .textFieldStyle(.roundedBorder)
            .onAppear {
                store.send(.appear)
            }
            .onChange(of: store.didSave) { didSave in
                if didSave { dismiss() }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    var authorizationModePicker: some View {
        Picker(
            selection: $store.authorizationMode,
            content: {
                ForEach(
                    TabbyModel.AuthorizationMode.allCases,
                    id: \.rawValue
                ) { format in
                    switch format {
                    case .none:
                        Text("None").tag(format)
                    case .bearerToken:
                        Text("Bearer Token").tag(format)
                    case .basic:
                        Text("Basic").tag(format)
                    case .customHeaderField:
                        Text("Custom Header Field").tag(format)
                    }
                }
            },
            label: { Text("Format") }
        )
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    var form: some View {
        BaseURLTextField(
            title: "URL",
            prompt: Text("http://127.0.0.1:8080/v1/completions"),
            store: store.scope(
                state: \.urlSelection,
                action: \.urlSelection
            )
        )
        authorizationModePicker

        switch store.authorizationMode {
        case .none:
            EmptyView()
        case .basic:
            TextField("Username", text: $store.username)
            ApiKeyNamePicker(
                store: store.scope(
                    state: \.apiKeySelection,
                    action: \.apiKeySelection
                ),
                title: "Password"
            )
        case .customHeaderField:
            TextField("Header Name", text: $store.authorizationHeaderName)
            ApiKeyNamePicker(
                store: store.scope(
                    state: \.apiKeySelection,
                    action: \.apiKeySelection
                ),
                title: "Value"
            )
        case .bearerToken:
            ApiKeyNamePicker(
                store: store.scope(
                    state: \.apiKeySelection,
                    action: \.apiKeySelection
                ),
                title: "Token"
            )
        }
    }
}

#Preview("No Authorization") {
    TabbyModelEditView(
        store: .init(
            initialState: TabbyModel(
                url: "http://127.0.0.1", authorizationMode: .none, apiKeyName: "",
                authorizationHeaderName: "Key", username: "User"
            ).toState(),
            reducer: { TabbyModelEdit() }
        )
    )
}

#Preview("Bearer Token") {
    TabbyModelEditView(
        store: .init(
            initialState: TabbyModel(
                url: "http://127.0.0.1", authorizationMode: .bearerToken, apiKeyName: "",
                authorizationHeaderName: "Key", username: "User"
            ).toState(),
            reducer: { TabbyModelEdit() }
        )
    )
}

#Preview("Custom Header Field") {
    TabbyModelEditView(
        store: .init(
            initialState: TabbyModel(
                url: "http://127.0.0.1", authorizationMode: .customHeaderField, apiKeyName: "",
                authorizationHeaderName: "Key", username: "User"
            ).toState(),
            reducer: { TabbyModelEdit() }
        )
    )
}

#Preview("Basic") {
    TabbyModelEditView(
        store: .init(
            initialState: TabbyModel(
                url: "http://127.0.0.1", authorizationMode: .basic, apiKeyName: "",
                authorizationHeaderName: "Key", username: "User"
            ).toState(),
            reducer: { TabbyModelEdit() }
        )
    )
}
