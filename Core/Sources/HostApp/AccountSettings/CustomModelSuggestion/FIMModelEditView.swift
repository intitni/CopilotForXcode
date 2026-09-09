import AIModel
import ComposableArchitecture
import SwiftUI

@MainActor
struct FIMModelEditView: View {
    @Perception.Bindable var store: StoreOf<FIMModelEdit>

    @Environment(\.dismiss) var dismiss

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(spacing: 0) {
                    Form {
                        formatPicker

                        switch store.format {
                        case .mistral:
                            mistralForm
                        case .ollama:
                            ollama
                        case .ollamaCompatible:
                            ollamaCompatible
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
                    FIMModel.Format.allCases,
                    id: \.rawValue
                ) { format in
                    switch format {
                    case .mistral:
                        Text("Mistral").tag(format)
                    case .ollama:
                        Text("Ollama").tag(format)
                    case .ollamaCompatible:
                        Text("Ollama Compatible").tag(format)
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
    var mistralForm: some View {
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
                ? Text("https://api.mistral.ai/v1/fim/completions")
                : Text("https://api.mistral.ai")
        ) {
            if !store.baseURLSelection.isFullURL {
                Text("/v1/fim/completions")
            }
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
                """
                 Compatible with:
                - Mistral FIM API
                - DeepSeek FIM API
                
                or any API that takes a prompt and a suffix and responds with 
                an OpenAI-compatible streaming response, using bearer token authentication.
                """
            )
        }
        .padding(.vertical)
    }

    @ViewBuilder
    var ollama: some View {
        baseURLTextField(
            title: "",
            prompt: Text("https://127.0.0.1:11434")
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

    @ViewBuilder
    var ollamaCompatible: some View {
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
                ? Text("https://127.0.0.1:11434/api/generate")
                : Text("https://127.0.0.1:11434")
        ) {
            if !store.baseURLSelection.isFullURL {
                Text("/api/generate")
            }
        }

        Picker(
            selection: $store.authenticationMode,
            content: {
                Text("Bearer Token").tag(FIMModel.Info.AuthenticationMode.bearerToken)
                Text("Header Field").tag(FIMModel.Info.AuthenticationMode.header)
            },
            label: { Text("Authentication Mode") }
        )
        .pickerStyle(.segmented)

        if store.authenticationMode == .header {
            TextField("Header Field Name", text: $store.authenticationHeaderFieldName)
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

        VStack(alignment: .leading, spacing: 8) {
            Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                " Use with any API that has the same format as Ollama. For more details, please visit [https://ollama.com](https://ollama.com)"
            )
        }
        .padding(.vertical)
    }
}

#Preview("Mistral") {
    FIMModelEditView(
        store: .init(
            initialState: FIMModel(
                id: "3",
                name: "Test Model 3",
                format: .mistral,
                info: .init(
                    apiKeyName: "key",
                    baseURL: "apple.com",
                    maxTokens: 3000,
                    modelName: "gpt-3.5-turbo"
                )
            ).toState(),
            reducer: { FIMModelEdit() }
        )
    )
}
