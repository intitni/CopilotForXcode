import AIModel
import ComposableArchitecture
import CustomSuggestionService
import Preferences
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
    var openAI: some View {
        baseURLTextField(prompt: Text("https://api.openai.com")) {
            Text("/v1/completions")
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
                " To get an API key, please visit [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)"
            )
        }
        .padding(.vertical)
    }

    @ViewBuilder
    var azureOpenAI: some View {
        baseURLTextField(prompt: Text("https://xxxx.openai.azure.com"))
        apiKeyNamePicker

        TextField("Deployment Name", text: $store.modelName)

        maxTokensTextField
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
        apiKeyNamePicker

        TextField("Model Name", text: $store.modelName)

        maxTokensTextField
    }

    @ViewBuilder
    var googleAI: some View {
        apiKeyNamePicker

        TextField("Model Name", text: $store.modelName)
            .overlay(alignment: .trailing) {
                Picker(
                    "",
                    selection: $store.modelName,
                    content: {
                        if GoogleGeminiService.KnownModels(rawValue: store.modelName) == nil {
                            Text("Custom Model").tag(store.modelName)
                        }
                        ForEach(GoogleGeminiService.KnownModels.allCases, id: \.self) { model in
                            Text(model.rawValue).tag(model.rawValue)
                        }
                    }
                )
                .frame(width: 20)
            }

        maxTokensTextField
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

