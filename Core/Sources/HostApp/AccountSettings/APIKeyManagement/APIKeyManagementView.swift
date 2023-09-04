import ComposableArchitecture
import SwiftUI

struct APIKeyManagementView: View {
    let store: StoreOf<APIKeyManagement>

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    store.send(.closeButtonClicked)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .buttonStyle(.plain)
                Text("API Keys")
                Spacer()
                Button(action: {
                    store.send(.addButtonClicked)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .buttonStyle(.plain)
            }
            .background(Color(nsColor: .separatorColor))

            List {
                WithViewStore(store, observe: { $0.availableAPIKeyNames }) { viewStore in
                    ForEach(viewStore.state, id: \.self) { name in
                        HStack {
                            Text(name)
                                .contextMenu {
                                    Button("Remove") {
                                        viewStore.send(.deleteButtonClicked(name: name))
                                    }
                                }
                            Spacer()

                            Button(action: {
                                viewStore.send(.deleteButtonClicked(name: name))
                            }) {
                                Image(systemName: "trash.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .removeBackground()
            .overlay {
                WithViewStore(store, observe: { $0.availableAPIKeyNames }) { viewStore in
                    if viewStore.state.isEmpty {
                        Text("""
                        Empty
                        Add a new key by clicking the add button
                        """)
                        .multilineTextAlignment(.center)
                        .padding()
                    }
                }
            }
        }
        .focusable(false)
        .frame(width: 300, height: 400)
        .background(.thickMaterial)
        .onAppear {
            store.send(.appear)
        }
        .sheet(store: store.scope(
            state: \.$apiKeySubmission,
            action: APIKeyManagement.Action.apiKeySubmission
        )) { store in
            APIKeySubmissionView(store: store)
                .frame(minWidth: 400)
        }
    }
}

struct APIKeySubmissionView: View {
    let store: StoreOf<APIKeySubmission>

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Form {
                    WithViewStore(store, removeDuplicates: { $0.name == $1.name }) { viewStore in
                        TextField("Name", text: viewStore.$name)
                    }
                    WithViewStore(store, removeDuplicates: { $0.key == $1.key }) { viewStore in
                        SecureField("Key", text: viewStore.$key)
                    }
                }.padding()

                Divider()

                HStack {
                    Spacer()

                    Button("Cancel") { store.send(.cancelButtonClicked) }
                        .keyboardShortcut(.cancelAction)

                    Button("Save", action: { store.send(.saveButtonClicked) })
                        .keyboardShortcut(.defaultAction)
                }.padding()
            }
        }
        .textFieldStyle(.roundedBorder)
    }
}

class APIKeyManagementView_Preview: PreviewProvider {
    static var previews: some View {
        APIKeyManagementView(
            store: .init(
                initialState: .init(
                    availableAPIKeyNames: ["test1", "test2"]
                ),
                reducer: APIKeyManagement()
            )
        )
    }
}

class APIKeySubmissionView_Preview: PreviewProvider {
    static var previews: some View {
        APIKeySubmissionView(
            store: .init(
                initialState: .init(),
                reducer: APIKeySubmission()
            )
        )
    }
}

