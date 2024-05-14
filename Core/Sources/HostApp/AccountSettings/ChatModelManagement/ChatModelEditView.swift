import AIModel
import ComposableArchitecture
import OpenAIService
import Preferences
import SwiftUI

@MainActor
struct ChatModelEditView: View {
    @Perception.Bindable var store: StoreOf<ChatModelEdit>

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Form {
                    nameTextField
                    formatPicker

                    WithPerceptionTracking {
                        switch store.format {
                        case .openAI:
                            openAI
                        case .azureOpenAI:
                            azureOpenAI
                        case .openAICompatible:
                            openAICompatible
                        case .googleAI:
                            googleAI
                        case .ollama:
                            ollama
                        case .claude:
                            claude
                        }
                    }
                }
                .padding()

                Divider()

                HStack {
                    WithPerceptionTracking {
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

    var nameTextField: some View {
        WithPerceptionTracking {
            TextField("Name", text: $store.name)
        }
    }

    var formatPicker: some View {
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

    var supportsFunctionCallingToggle: some View {
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

    var maxTokensTextField: some View {
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
            Text("/v1/chat/completions")
        }
        apiKeyNamePicker

        WithPerceptionTracking {
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
        }

        maxTokensTextField
        supportsFunctionCallingToggle

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

    @ViewBuilder
    var azureOpenAI: some View {
        baseURLTextField(prompt: Text("https://xxxx.openai.azure.com"))
        apiKeyNamePicker

        WithPerceptionTracking {
            TextField("Deployment Name", text: $store.modelName)
        }

        maxTokensTextField
        supportsFunctionCallingToggle
    }

    @ViewBuilder
    var openAICompatible: some View {
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

            baseURLTextField(
                title: "",
                prompt: store.isFullURL
                    ? Text("https://api.openai.com/v1/chat/completions")
                    : Text("https://api.openai.com")
            ) {
                if !store.isFullURL {
                    Text("/v1/chat/completions")
                }
            }
        }

        apiKeyNamePicker

        WithPerceptionTracking {
            TextField("Model Name", text: $store.modelName)
        }

        maxTokensTextField
        supportsFunctionCallingToggle
    }

    @ViewBuilder
    var googleAI: some View {
        baseURLTextField(prompt: Text("https://generativelanguage.googleapis.com")) {
            Text("/v1")
        }

        apiKeyNamePicker

        WithPerceptionTracking {
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
        }

        maxTokensTextField

        WithPerceptionTracking {
            TextField("API Version", text: $store.apiVersion, prompt: Text("v1"))
        }
    }

    @ViewBuilder
    var ollama: some View {
        baseURLTextField(prompt: Text("http://127.0.0.1:11434")) {
            Text("/api/chat")
        }

        WithPerceptionTracking {
            TextField("Model Name", text: $store.modelName)
        }

        maxTokensTextField

        WithPerceptionTracking {
            TextField(text: $store.ollamaKeepAlive, prompt: Text("Default Value")) {
                Text("Keep Alive")
            }
        }

        VStack(alignment: .leading, spacing: 8) {
            Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                " For more details, please visit [https://ollama.com](https://ollama.com)."
            )
        }
        .padding(.vertical)
    }

    @ViewBuilder
    var claude: some View {
        baseURLTextField(prompt: Text("https://api.anthropic.com")) {
            Text("/v1/messages")
        }

        apiKeyNamePicker

        WithPerceptionTracking {
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
        }

        maxTokensTextField

        VStack(alignment: .leading, spacing: 8) {
            Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                " For more details, please visit [https://anthropic.com](https://anthropic.com)."
            )
        }
        .padding(.vertical)
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

