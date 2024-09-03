import AIModel
import ComposableArchitecture
import OpenAIService
import Preferences
import SwiftUI

@MainActor
struct ChatModelEditView: View {
    @Perception.Bindable var store: StoreOf<ChatModelEdit>

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(spacing: 0) {
                    Form {
                        NameTextField(store: store)
                        FormatPicker(store: store)

                        switch store.format {
                        case .openAI:
                            OpenAIForm(store: store)
                        case .azureOpenAI:
                            AzureOpenAIForm(store: store)
                        case .openAICompatible:
                            OpenAICompatibleForm(store: store)
                        case .googleAI:
                            GoogleAIForm(store: store)
                        case .ollama:
                            OllamaForm(store: store)
                        case .claude:
                            ClaudeForm(store: store)
                        }
                    }
                    .padding()

                    Divider()

                    HStack {
                        HStack(spacing: 8) {
                            Button("Test") {
                                store.send(.testButtonClicked)
                            }
                            .disabled(store.isTesting)

                            if store.isTesting {
                                ProgressView()
                                    .controlSize(.small)
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
            .fixedSize(horizontal: false, vertical: true)
            .handleToast(namespace: "ChatModelEdit")
        }
    }

    struct NameTextField: View {
        @Perception.Bindable var store: StoreOf<ChatModelEdit>
        var body: some View {
            WithPerceptionTracking {
                TextField("Name", text: $store.name)
            }
        }
    }

    struct FormatPicker: View {
        @Perception.Bindable var store: StoreOf<ChatModelEdit>
        var body: some View {
            WithPerceptionTracking {
                Picker(
                    selection: $store.format,
                    content: {
                        ForEach(
                            ChatModel.Format.allCases,
                            id: \.rawValue
                        ) { format in
                            switch format {
                            case .openAI:
                                Text("OpenAI").tag(format)
                            case .azureOpenAI:
                                Text("Azure OpenAI").tag(format)
                            case .openAICompatible:
                                Text("OpenAI Compatible").tag(format)
                            case .googleAI:
                                Text("Google Generative AI").tag(format)
                            case .ollama:
                                Text("Ollama").tag(format)
                            case .claude:
                                Text("Claude").tag(format)
                            }
                        }
                    },
                    label: { Text("Format") }
                )
                .pickerStyle(.segmented)
            }
        }
    }

    struct BaseURLTextField<V: View>: View {
        let store: StoreOf<ChatModelEdit>
        var title: String = "Base URL"
        let prompt: Text?
        @ViewBuilder var trailingContent: () -> V

        var body: some View {
            WithPerceptionTracking {
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
        }
    }

    struct SupportsFunctionCallingToggle: View {
        @Perception.Bindable var store: StoreOf<ChatModelEdit>
        var body: some View {
            WithPerceptionTracking {
                Toggle(
                    "Supports Function Calling",
                    isOn: $store.supportsFunctionCalling
                )

                Text(
                    "Function calling is required by some features, if this model doesn't support function calling, you should turn it off to avoid undefined behaviors."
                )
                .foregroundColor(.secondary)
                .font(.callout)
                .dynamicHeightTextInFormWorkaround()
            }
        }
    }

    struct MaxTokensTextField: View {
        @Perception.Bindable var store: StoreOf<ChatModelEdit>

        var body: some View {
            WithPerceptionTracking {
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
        }
    }

    struct ApiKeyNamePicker: View {
        let store: StoreOf<ChatModelEdit>
        var body: some View {
            WithPerceptionTracking {
                APIKeyPicker(store: store.scope(
                    state: \.apiKeySelection,
                    action: \.apiKeySelection
                ))
            }
        }
    }

    struct OpenAIForm: View {
        @Perception.Bindable var store: StoreOf<ChatModelEdit>
        var body: some View {
            WithPerceptionTracking {
                BaseURLTextField(store: store, prompt: Text("https://api.openai.com")) {
                    Text("/v1/chat/completions")
                }
                ApiKeyNamePicker(store: store)

                TextField("Model Name", text: $store.modelName)
                    .overlay(alignment: .trailing) {
                        Picker(
                            "",
                            selection: $store.modelName,
                            content: {
                                if ChatGPTModel(rawValue: store.modelName) == nil {
                                    Text("Custom Model").tag(store.modelName)
                                }
                                ForEach(ChatGPTModel.allCases, id: \.self) { model in
                                    Text(model.rawValue).tag(model.rawValue)
                                }
                            }
                        )
                        .frame(width: 20)
                    }

                MaxTokensTextField(store: store)
                SupportsFunctionCallingToggle(store: store)
                
                TextField(text: $store.openAIOrganizationID, prompt: Text("Optional")) {
                    Text("Organization ID")
                }

                TextField(text: $store.openAIProjectID, prompt: Text("Optional")) {
                    Text("Project ID")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                        " To get an API key, please visit [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys)"
                    )

                    Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                        " If you don't have access to GPT-4, you may need to visit [https://platform.openai.com/account/billing/overview](https://platform.openai.com/account/billing/overview) to buy some credits. A ChatGPT Plus subscription is not enough to access GPT-4 through API."
                    )
                }
                .padding(.vertical)
            }
        }
    }

    struct AzureOpenAIForm: View {
        @Perception.Bindable var store: StoreOf<ChatModelEdit>
        var body: some View {
            WithPerceptionTracking {
                BaseURLTextField(store: store, prompt: Text("https://xxxx.openai.azure.com")) {
                    EmptyView()
                }
                ApiKeyNamePicker(store: store)

                TextField("Deployment Name", text: $store.modelName)

                MaxTokensTextField(store: store)
                SupportsFunctionCallingToggle(store: store)
            }
        }
    }

    struct OpenAICompatibleForm: View {
        @Perception.Bindable var store: StoreOf<ChatModelEdit>

        var body: some View {
            WithPerceptionTracking {
                Picker(
                    selection: $store.baseURLSelection.isFullURL,
                    content: {
                        Text("Base URL").tag(false)
                        Text("Full URL").tag(true)
                    },
                    label: { Text("URL") }
                )
                .pickerStyle(.segmented)

                BaseURLTextField(
                    store: store,
                    title: "",
                    prompt: store.isFullURL
                        ? Text("https://api.openai.com/v1/chat/completions")
                        : Text("https://api.openai.com")
                ) {
                    if !store.isFullURL {
                        Text("/v1/chat/completions")
                    }
                }

                ApiKeyNamePicker(store: store)

                TextField("Model Name", text: $store.modelName)

                MaxTokensTextField(store: store)
                SupportsFunctionCallingToggle(store: store)

                Toggle(isOn: $store.enforceMessageOrder) {
                    Text("Enforce message order to be user/assistant alternated")
                }
            }
        }
    }

    struct GoogleAIForm: View {
        @Perception.Bindable var store: StoreOf<ChatModelEdit>

        var body: some View {
            WithPerceptionTracking {
                BaseURLTextField(
                    store: store,
                    prompt: Text("https://generativelanguage.googleapis.com")
                ) {
                    Text("/v1")
                }

                ApiKeyNamePicker(store: store)

                TextField("Model Name", text: $store.modelName)
                    .overlay(alignment: .trailing) {
                        Picker(
                            "",
                            selection: $store.modelName,
                            content: {
                                if GoogleGenerativeAIModel(rawValue: store.modelName) == nil {
                                    Text("Custom Model").tag(store.modelName)
                                }
                                ForEach(GoogleGenerativeAIModel.allCases, id: \.self) { model in
                                    Text(model.rawValue).tag(model.rawValue)
                                }
                            }
                        )
                        .frame(width: 20)
                    }

                MaxTokensTextField(store: store)

                TextField("API Version", text: $store.apiVersion, prompt: Text("v1"))
            }
        }
    }

    struct OllamaForm: View {
        @Perception.Bindable var store: StoreOf<ChatModelEdit>
        var body: some View {
            WithPerceptionTracking {
                BaseURLTextField(store: store, prompt: Text("http://127.0.0.1:11434")) {
                    Text("/api/chat")
                }

                TextField("Model Name", text: $store.modelName)

                MaxTokensTextField(store: store)

                TextField(text: $store.ollamaKeepAlive, prompt: Text("Default Value")) {
                    Text("Keep Alive")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                        " For more details, please visit [https://ollama.com](https://ollama.com)."
                    )
                }
                .padding(.vertical)
            }
        }
    }

    struct ClaudeForm: View {
        @Perception.Bindable var store: StoreOf<ChatModelEdit>
        var body: some View {
            WithPerceptionTracking {
                BaseURLTextField(store: store, prompt: Text("https://api.anthropic.com")) {
                    Text("/v1/messages")
                }

                ApiKeyNamePicker(store: store)

                TextField("Model Name", text: $store.modelName)
                    .overlay(alignment: .trailing) {
                        Picker(
                            "",
                            selection: $store.modelName,
                            content: {
                                if ClaudeChatCompletionsService
                                    .KnownModel(rawValue: store.modelName) == nil
                                {
                                    Text("Custom Model").tag(store.modelName)
                                }
                                ForEach(
                                    ClaudeChatCompletionsService.KnownModel.allCases,
                                    id: \.self
                                ) { model in
                                    Text(model.rawValue).tag(model.rawValue)
                                }
                            }
                        )
                        .frame(width: 20)
                    }

                MaxTokensTextField(store: store)

                VStack(alignment: .leading, spacing: 8) {
                    Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                        " For more details, please visit [https://anthropic.com](https://anthropic.com)."
                    )
                }
                .padding(.vertical)
            }
        }
    }
}

#Preview("OpenAI") {
    ChatModelEditView(
        store: .init(
            initialState: ChatModel(
                id: "3",
                name: "Test Model 3",
                format: .openAI,
                info: .init(
                    apiKeyName: "key",
                    baseURL: "apple.com",
                    maxTokens: 3000,
                    supportsFunctionCalling: false,
                    modelName: "gpt-3.5-turbo"
                )
            ).toState(),
            reducer: { ChatModelEdit() }
        )
    )
}

#Preview("OpenAI Compatible") {
    ChatModelEditView(
        store: .init(
            initialState: ChatModel(
                id: "3",
                name: "Test Model 3",
                format: .openAICompatible,
                info: .init(
                    apiKeyName: "key",
                    baseURL: "apple.com",
                    isFullURL: false,
                    maxTokens: 3000,
                    supportsFunctionCalling: false,
                    modelName: "gpt-3.5-turbo"
                )
            ).toState(),
            reducer: { ChatModelEdit() }
        )
    )
}

