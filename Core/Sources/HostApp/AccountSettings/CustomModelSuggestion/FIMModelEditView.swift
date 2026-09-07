import AIModel
import ComposableArchitecture
import CustomSuggestionService
import Preferences
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
                            dismiss()
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
        title: String = "Base URL",
        prompt: Text?,
        @ViewBuilder trailingContent: @escaping () -> V
    ) -> some View {
        BaseURLPicker(
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
        title: String = "Base URL",
        prompt: Text?
    ) -> some View {
        baseURLTextField(title: title, prompt: prompt, trailingContent: { EmptyView() })
    }

    var maxTokensTextField: some View {
        HStack {
            let textFieldBinding = Binding(
                get: { String(store.maxTokens) },
                set: {
                    if let selectionMaxToken = Int($0) {
                        $store.maxTokens.wrappedValue = selectionMaxToken
                    } else {
                        $store.maxTokens.wrappedValue = 0
                    }
                }
            )

            TextField(text: textFieldBinding) {
                Text("Context Window")
                    .multilineTextAlignment(.trailing)
            }
            .overlay(alignment: .trailing) {
                Stepper(
                    value: $store.maxTokens,
                    in: 0...Int.max,
                    step: 100
                ) {
                    EmptyView()
                }
            }
            .foregroundColor({
                guard let max = store.suggestedMaxTokens else {
                    return .primary
                }
                if store.maxTokens > max {
                    return .red
                }
                return .primary
            }() as Color)

            if let max = store.suggestedMaxTokens {
                Text("Max: \(max)")
            }
        }
    }

    @ViewBuilder
    var apiKeyNamePicker: some View {
        APIKeyPicker(store: store.scope(
            state: \.apiKeySelection,
            action: \.apiKeySelection
        ))
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
        apiKeyNamePicker

        TextField("Model Name", text: $store.modelName)
            .overlay(alignment: .trailing) {
                Picker(
                    "",
                    selection: $store.modelName,
                    content: {
                        if CustomSuggestionService.OpenAIService.ChatCompletionModels(rawValue: store.modelName) == nil {
                            Text("Custom Model").tag(store.modelName)
                        }
                        ForEach(CustomSuggestionService.OpenAIService.ChatCompletionModels.allCases, id: \.self) { model in
                            Text(model.rawValue).tag(model.rawValue)
                        }
                    }
                )
                .frame(width: 20)
            }

        maxTokensTextField
        
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

        maxTokensTextField

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

        apiKeyNamePicker

        TextField("Model Name", text: $store.modelName)

        maxTokensTextField

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

