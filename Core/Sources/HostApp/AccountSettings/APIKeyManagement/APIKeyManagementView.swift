import ComposableArchitecture
import SharedUIComponents
import SwiftUI

struct APIKeyManagementView: View {
    @Perception.Bindable var store: StoreOf<APIKeyManagement>

    var body: some View {
        WithPerceptionTracking {
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
                    ForEach(store.availableAPIKeyNames, id: \.self) { name in
                        WithPerceptionTracking {
                            HStack {
                                Text(name)
                                    .contextMenu {
                                        Button("Remove") {
                                            store.send(.deleteButtonClicked(name: name))
                                        }
                                    }
                                Spacer()

                                Button(action: {
                                    store.send(.deleteButtonClicked(name: name))
                                }) {
                                    Image(systemName: "trash.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .modify { view in
                        if #available(macOS 13.0, *) {
                            view.listRowSeparator(.hidden).listSectionSeparator(.hidden)
                        } else {
                            view
                        }
                    }
                }
                .removeBackground()
                .overlay {
                    if store.availableAPIKeyNames.isEmpty {
                        Text("""
                        Empty
                        Add a new key by clicking the add button
                        """)
                        .multilineTextAlignment(.center)
                        .padding()
                    }
                }
            }
            .focusable(false)
            .frame(width: 300, height: 400)
            .background(.thickMaterial)
            .onAppear {
                store.send(.appear)
            }
            .sheet(item: $store.scope(
                state: \.apiKeySubmission,
                action: \.apiKeySubmission
            )) { store in
                APIKeySubmissionView(store: store)
                    .frame(minWidth: 400)
            }
        }
    }
}

struct APIKeySubmissionView: View {
    @Perception.Bindable var store: StoreOf<APIKeySubmission>

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(spacing: 0) {
                    Form {
                        TextField("Name", text: $store.name)
                        SecureField("Key", text: $store.key)
                    }
                    .padding()

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
}

class APIKeyManagementView_Preview: PreviewProvider {
    static var previews: some View {
        APIKeyManagementView(
            store: .init(
                initialState: .init(
                    availableAPIKeyNames: ["test1", "test2"]
                ),
                reducer: { APIKeyManagement() }
            )
        )
    }
}

class APIKeySubmissionView_Preview: PreviewProvider {
    static var previews: some View {
        APIKeySubmissionView(
            store: .init(
                initialState: .init(),
                reducer: { APIKeySubmission() }
            )
        )
    }
}

