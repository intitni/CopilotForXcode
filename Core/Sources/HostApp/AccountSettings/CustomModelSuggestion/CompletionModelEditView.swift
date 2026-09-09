import AIModel
import ComposableArchitecture
import SwiftUI

@MainActor
struct CompletionModelEditView: View {
    @Perception.Bindable var store: StoreOf<CompletionModelEdit>

    @Environment(\.dismiss) var dismiss

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(spacing: 0) {
                    Form {
                        formatPicker

                        switch store.format {
                        case .openAI:
                            openAI
                        case .azureOpenAI:
                            azureOpenAI
                        case .openAICompatible:
                            openAICompatible
                        case .ollama:
                            ollama
                        case .unknown:
                            EmptyView()
                        }
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

    var formatPicker: some View {
        Picker(
            selection: $store.format,
            content: {
                ForEach(
                    CompletionModel.Format.allCases,
                    id: \.rawValue
                ) { format in
                    switch format {
                    case .openAI:
                        Text("OpenAI").tag(format)
                    case .azureOpenAI:
                        Text("Azure OpenAI").tag(format)
                    case .openAICompatible:
                        Text("OpenAI Compatible").tag(format)
                    case .ollama:
                        Text("Ollama").tag(format)
                    case .unknown:
                        EmptyView()
                    }
                }
            },
            label: { Text("Format") }
        )
        .pickerStyle(.segmented)
    }

    func baseURLTextField<V: View>(
        title: LocalizedStringKey = "Base URL",
        prompt: Text?,
        @ViewBuilder trailingContent: @escaping () -> V
    ) -> some View {
        BaseURLTextField(
            title: title,
            prompt: prompt,
            store: store.scope(
                state: \.baseURLSelection,
                action: \.baseURLSelection
            ),
            trailingContent: trailingContent
        )
    }

    func baseURLTextField(
        title: LocalizedStringKey = "Base URL",
        prompt: Text?
    ) -> some View {
        baseURLTextField(title: title, prompt: prompt, trailingContent: { EmptyView() })
    }

    @ViewBuilder
    var openAI: some View {
        baseURLTextField(prompt: Text("https://api.openai.com")) {
            Text("/v1/completions")
        }
        ApiKeyNamePicker(store: store.scope(
            state: \.apiKeySelection,
            action: \.apiKeySelection
        ))

        TextField("Model Name", text: $store.modelName)
            .overlay(alignment: .trailing) {
                Picker(
                    "",
                    selection: $store.modelName,
                    content: {
                        if !store.availableModelNames.contains(store.modelName) {
                            Text("Custom Model").tag(store.modelName)
                        }
                        ForEach(store.availableModelNames, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                )
                .frame(width: 20)
            }

        MaxTokensTextField(
            maxTokens: $store.maxTokens,
            suggestedMaxTokens: store.suggestedMaxTokens
        )

        VStack(alignment: .leading, spacing: 8) {
            Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                " To get an API key, please visit [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)"
            )
        }
        .padding(.vertical)
    }

    @ViewBuilder
    var azureOpenAI: some View {
        baseURLTextField(prompt: Text("https://xxxx.openai.azure.com"))
        ApiKeyNamePicker(store: store.scope(
            state: \.apiKeySelection,
            action: \.apiKeySelection
        ))

        TextField("Deployment Name", text: $store.modelName)

        MaxTokensTextField(
            maxTokens: $store.maxTokens,
            suggestedMaxTokens: store.suggestedMaxTokens
        )
    }

    @ViewBuilder
    var openAICompatible: some View {
        Picker(
            selection: $store.baseURLSelection.isFullURL,
            content: {
                Text("Base URL").tag(false)
                Text("Full URL").tag(true)
            },
            label: { Text("URL") }
        )
        .pickerStyle(.segmented)

        baseURLTextField(
            title: "",
            prompt: store.baseURLSelection.isFullURL
                ? Text("https://api.openai.com/v1/completions")
                : Text("https://api.openai.com")
        ) {
            if !store.baseURLSelection.isFullURL {
                Text("/v1/completions")
            }
        }
        ApiKeyNamePicker(store: store.scope(
            state: \.apiKeySelection,
            action: \.apiKeySelection
        ))

        TextField("Model Name", text: $store.modelName)

        MaxTokensTextField(
            maxTokens: $store.maxTokens,
            suggestedMaxTokens: store.suggestedMaxTokens
        )
    }

    @ViewBuilder
    var ollama: some View {
        baseURLTextField(
            title: "",
            prompt: Text("https://127.0.0.1:11434/api/generate")
        ) {
            Text("/api/generate")
        }

        TextField("Model Name", text: $store.modelName)

        MaxTokensTextField(
            maxTokens: $store.maxTokens,
            suggestedMaxTokens: store.suggestedMaxTokens
        )

        TextField(text: $store.ollamaKeepAlive, prompt: Text("Default Value")) {
            Text("Keep Alive")
        }

        VStack(alignment: .leading, spacing: 8) {
            Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                " For more details, please visit [https://ollama.com](https://ollama.com)"
            )
        }
        .padding(.vertical)
    }
}

#Preview("OpenAI") {
    CompletionModelEditView(
        store: .init(
            initialState: CompletionModel(
                id: "3",
                name: "Test Model 3",
                format: .openAI,
                info: .init(
                    apiKeyName: "key",
                    baseURL: "apple.com",
                    maxTokens: 3000,
                    modelName: "gpt-3.5-turbo"
                )
            ).toState(),
            reducer: { CompletionModelEdit() }
        )
    )
}

#Preview("OpenAI Compatible") {
    CompletionModelEditView(
        store: .init(
            initialState: CompletionModel(
                id: "3",
                name: "Test Model 3",
                format: .openAICompatible,
                info: .init(
                    apiKeyName: "key",
                    baseURL: "apple.com",
                    maxTokens: 3000,
                    modelName: "gpt-3.5-turbo"
                )
            ).toState(),
            reducer: { CompletionModelEdit() }
        )
    )
}
