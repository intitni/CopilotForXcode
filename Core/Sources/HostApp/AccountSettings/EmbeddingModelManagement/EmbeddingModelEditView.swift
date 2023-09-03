import AIModel
import ComposableArchitecture
import Preferences
import SwiftUI

@MainActor
struct EmbeddingModelEditView: View {
    let store: StoreOf<EmbeddingModelEdit>

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Form {
                    nameTextField
                    formatPicker

                    WithViewStore(store, observe: { $0.format }) { viewStore in
                        switch viewStore.state {
                        case .openAI:
                            openAI
                        case .azureOpenAI:
                            azureOpenAI
                        case .openAICompatible:
                            openAICompatible
                        }
                    }
                }
                .padding()

                Divider()

                HStack {
                    WithViewStore(store, observe: { $0.isTesting }) { viewStore in
                        HStack(spacing: 8) {
                            Button("Test") {
                                store.send(.testButtonClicked)
                            }
                            .disabled(viewStore.state)

                            if viewStore.state {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }

                    Spacer()

                    Button("Cancel") {
                        store.send(.cancelButtonClicked)
                    }
                    .keyboardShortcut(.cancelAction)

                    Button(action: { store.send(.saveButtonClicked) }) {
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
    }

    var nameTextField: some View {
        WithViewStore(store, removeDuplicates: { $0.name == $1.name }) { viewStore in
            TextField("Name", text: viewStore.$name)
        }
    }

    var formatPicker: some View {
        WithViewStore(store, removeDuplicates: { $0.format == $1.format }) { viewStore in
            Picker(
                selection: viewStore.$format,
                content: {
                    ForEach(
                        EmbeddingModel.Format.allCases,
                        id: \.rawValue
                    ) { format in
                        switch format {
                        case .openAI:
                            Text("OpenAI").tag(format)
                        case .azureOpenAI:
                            Text("Azure OpenAI").tag(format)
                        case .openAICompatible:
                            Text("OpenAI Compatible").tag(format)
                        }
                    }
                },
                label: { Text("Format") }
            )
            .pickerStyle(.segmented)
        }
    }

    func baseURLTextField(prompt: Text?) -> some View {
        BaseURLPicker(
            prompt: prompt,
            store: store.scope(
                state: \.baseURLSelection,
                action: EmbeddingModelEdit.Action.baseURLSelection
            )
        )
    }

    struct MaxTokensTextField: Equatable {
        @BindingViewState var maxTokens: Int
        var suggestedMaxTokens: Int?
    }

    var maxTokensTextField: some View {
        WithViewStore(
            store,
            observe: {
                MaxTokensTextField(
                    maxTokens: $0.$maxTokens,
                    suggestedMaxTokens: $0.suggestedMaxTokens
                )
            }
        ) { viewStore in
            HStack {
                let textFieldBinding = Binding(
                    get: { String(viewStore.state.maxTokens) },
                    set: {
                        if let selectionMaxToken = Int($0) {
                            viewStore.$maxTokens.wrappedValue = selectionMaxToken
                        } else {
                            viewStore.$maxTokens.wrappedValue = 0
                        }
                    }
                )

                TextField(text: textFieldBinding) {
                    Text("Max Input Tokens")
                        .multilineTextAlignment(.trailing)
                }
                .overlay(alignment: .trailing) {
                    Stepper(
                        value: viewStore.$maxTokens,
                        in: 0...Int.max,
                        step: 100
                    ) {
                        EmptyView()
                    }
                }
                .foregroundColor({
                    guard let max = viewStore.state.suggestedMaxTokens else {
                        return .primary
                    }
                    if viewStore.state.maxTokens > max {
                        return .red
                    }
                    return .primary
                }() as Color)

                if let max = viewStore.state.suggestedMaxTokens {
                    Text("Max: \(max)")
                }
            }
        }
    }

    struct APIKeyState: Equatable {
        @BindingViewState var apiKeyName: String
        var availableAPIKeys: [String]
    }

    @ViewBuilder
    var apiKeyNamePicker: some View {
        APIKeyPicker(store: store.scope(
            state: \.apiKeySelection,
            action: EmbeddingModelEdit.Action.apiKeySelection
        ))
    }

    @ViewBuilder
    var openAI: some View {
        baseURLTextField(prompt: Text("https://api.openai.com"))
        apiKeyNamePicker

        WithViewStore(
            store,
            removeDuplicates: { $0.modelName == $1.modelName }
        ) { viewStore in
            TextField("Model Name", text: viewStore.$modelName)
                .overlay(alignment: .trailing) {
                    Picker(
                        "",
                        selection: viewStore.$modelName,
                        content: {
                            ForEach(ChatGPTModel.allCases, id: \.self) { model in
                                Text(model.rawValue).tag(model.rawValue)
                            }
                        }
                    )
                    .frame(width: 20)
                }
        }

        maxTokensTextField
    }

    @ViewBuilder
    var azureOpenAI: some View {
        baseURLTextField(prompt: Text("https://xxxx.openai.azure.com"))
        apiKeyNamePicker

        WithViewStore(
            store,
            removeDuplicates: { $0.modelName == $1.modelName }
        ) { viewStore in
            TextField("Deployment Name", text: viewStore.$modelName)
        }

        maxTokensTextField
    }

    @ViewBuilder
    var openAICompatible: some View {
        baseURLTextField(prompt: Text("https://"))
        apiKeyNamePicker

        WithViewStore(
            store,
            removeDuplicates: { $0.modelName == $1.modelName }
        ) { viewStore in
            TextField("Model Name", text: viewStore.$modelName)
        }

        maxTokensTextField
    }
}

class EmbeddingModelManagementView_Editing_Previews: PreviewProvider {
    static var previews: some View {
        EmbeddingModelEditView(
            store: .init(
                initialState: .init(model: EmbeddingModel(
                    id: "3",
                    name: "Test Model 3",
                    format: .openAICompatible,
                    info: .init(
                        apiKeyName: "key",
                        baseURL: "apple.com",
                        maxTokens: 3000,
                        modelName: "gpt-3.5-turbo"
                    )
                )),
                reducer: EmbeddingModelEdit()
            )
        )
    }
}

