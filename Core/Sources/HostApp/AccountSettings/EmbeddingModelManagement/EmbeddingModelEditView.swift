import AIModel
import ComposableArchitecture
import Preferences
import SwiftUI

@MainActor
struct EmbeddingModelEditView: View {
    @Perception.Bindable var store: StoreOf<EmbeddingModelEdit>

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
                        case .ollama:
                            OllamaForm(store: store)
                        case .gitHubCopilot:
                            GitHubCopilotForm(store: store)
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
            .handleToast(namespace: "EmbeddingModelEdit")
        }
    }

    struct NameTextField: View {
        @Perception.Bindable var store: StoreOf<EmbeddingModelEdit>
        var body: some View {
            WithPerceptionTracking {
                TextField("Name", text: $store.name)
            }
        }
    }

    struct FormatPicker: View {
        @Perception.Bindable var store: StoreOf<EmbeddingModelEdit>
        var body: some View {
            WithPerceptionTracking {
                Picker(
                    selection: Binding(
                        get: { .init(store.format) },
                        set: { store.send(.selectModelFormat($0)) }
                    ),
                    content: {
                        ForEach(
                            EmbeddingModelEdit.ModelFormat.allCases,
                            id: \.self
                        ) { format in
                            switch format {
                            case .openAI:
                                Text("OpenAI")
                            case .azureOpenAI:
                                Text("Azure OpenAI")
                            case .ollama:
                                Text("Ollama")
                            case .openAICompatible:
                                Text("OpenAI Compatible")
                            case .mistralOpenAICompatible:
                                Text("Mistral (OpenAI Compatible)")
                            case .voyageAIOpenAICompatible:
                                Text("Voyage (OpenAI Compatible)")
                            case .gitHubCopilot:
                                Text("GitHub Copilot")
                            }
                        }
                    },
                    label: { Text("Format") }
                )
                .pickerStyle(.menu)
            }
        }
    }

    struct BaseURLTextField<V: View>: View {
        let store: StoreOf<EmbeddingModelEdit>
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

    struct MaxTokensTextField: View {
        @Perception.Bindable var store: StoreOf<EmbeddingModelEdit>

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
                        Text("Max Input Tokens")
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

    struct DimensionsTextField: View {
        @Perception.Bindable var store: StoreOf<EmbeddingModelEdit>

        var body: some View {
            WithPerceptionTracking {
                HStack {
                    let textFieldBinding = Binding(
                        get: { String(store.dimensions) },
                        set: {
                            if let selectionDimensions = Int($0) {
                                $store.dimensions.wrappedValue = selectionDimensions
                            } else {
                                $store.dimensions.wrappedValue = 0
                            }
                        }
                    )

                    TextField(text: textFieldBinding) {
                        Text("Dimensions")
                            .multilineTextAlignment(.trailing)
                    }
                    .overlay(alignment: .trailing) {
                        Stepper(
                            value: $store.dimensions,
                            in: 0...Int.max,
                            step: 100
                        ) {
                            EmptyView()
                        }
                    }
                    .foregroundColor({
                        if store.dimensions <= 0 {
                            return .red
                        }
                        return .primary
                    }() as Color)
                }

                Text("If you are not sure, run test to get the correct value.")
                    .font(.caption)
                    .dynamicHeightTextInFormWorkaround()
            }
        }
    }

    struct ApiKeyNamePicker: View {
        let store: StoreOf<EmbeddingModelEdit>
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
        @Perception.Bindable var store: StoreOf<EmbeddingModelEdit>

        var body: some View {
            WithPerceptionTracking {
                BaseURLTextField(store: store, prompt: Text("https://api.openai.com")) {
                    Text("/v1/embeddings")
                }
                ApiKeyNamePicker(store: store)

                TextField("Model Name", text: $store.modelName)
                    .overlay(alignment: .trailing) {
                        Picker(
                            "",
                            selection: $store.modelName,
                            content: {
                                if OpenAIEmbeddingModel(rawValue: store.modelName) == nil {
                                    Text("Custom Model").tag(store.modelName)
                                }
                                ForEach(OpenAIEmbeddingModel.allCases, id: \.self) { model in
                                    Text(model.rawValue).tag(model.rawValue)
                                }
                            }
                        )
                        .frame(width: 20)
                    }

                MaxTokensTextField(store: store)
                DimensionsTextField(store: store)

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
        @Perception.Bindable var store: StoreOf<EmbeddingModelEdit>
        var body: some View {
            WithPerceptionTracking {
                BaseURLTextField(store: store, prompt: Text("https://xxxx.openai.azure.com")) {
                    EmptyView()
                }
                ApiKeyNamePicker(store: store)

                TextField("Deployment Name", text: $store.modelName)

                MaxTokensTextField(store: store)
                DimensionsTextField(store: store)
            }
        }
    }

    struct OpenAICompatibleForm: View {
        @Perception.Bindable var store: StoreOf<EmbeddingModelEdit>
        @State var isEditingCustomHeader = false

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
                        ? Text("https://api.openai.com/v1/embeddings")
                        : Text("https://api.openai.com")
                ) {
                    if !store.isFullURL {
                        Text("/v1/embeddings")
                    }
                }

                ApiKeyNamePicker(store: store)

                TextField("Model Name", text: $store.modelName)

                MaxTokensTextField(store: store)
                DimensionsTextField(store: store)

                Button("Custom Headers") {
                    isEditingCustomHeader.toggle()
                }
            }.sheet(isPresented: $isEditingCustomHeader) {
                CustomHeaderSettingsView(headers: $store.customHeaders)
            }
        }
    }

    struct OllamaForm: View {
        @Perception.Bindable var store: StoreOf<EmbeddingModelEdit>
        @State var isEditingCustomHeader = false

        var body: some View {
            WithPerceptionTracking {
                BaseURLTextField(store: store, prompt: Text("http://127.0.0.1:11434")) {
                    Text("/api/embeddings")
                }

                ApiKeyNamePicker(store: store)

                TextField("Model Name", text: $store.modelName)

                MaxTokensTextField(store: store)
                DimensionsTextField(store: store)

                WithPerceptionTracking {
                    TextField(text: $store.ollamaKeepAlive, prompt: Text("Default Value")) {
                        Text("Keep Alive")
                    }
                }

                Button("Custom Headers") {
                    isEditingCustomHeader.toggle()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                        " For more details, please visit [https://ollama.com](https://ollama.com)."
                    )
                }
                .padding(.vertical)

            }.sheet(isPresented: $isEditingCustomHeader) {
                CustomHeaderSettingsView(headers: $store.customHeaders)
            }
        }
    }

    struct GitHubCopilotForm: View {
        @Perception.Bindable var store: StoreOf<EmbeddingModelEdit>
        @State var isEditingCustomHeader = false

        var body: some View {
            WithPerceptionTracking {
                TextField("Model Name", text: $store.modelName)
                    .overlay(alignment: .trailing) {
                        Picker(
                            "",
                            selection: $store.modelName,
                            content: {
                                if OpenAIEmbeddingModel(rawValue: store.modelName) == nil {
                                    Text("Custom Model").tag(store.modelName)
                                }
                                ForEach(OpenAIEmbeddingModel.allCases, id: \.self) { model in
                                    Text(model.rawValue).tag(model.rawValue)
                                }
                            }
                        )
                        .frame(width: 20)
                    }

                MaxTokensTextField(store: store)
                DimensionsTextField(store: store)

                Button("Custom Headers") {
                    isEditingCustomHeader.toggle()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                        " Please login in the GitHub Copilot settings to use the model."
                    )

                    Text(Image(systemName: "exclamationmark.triangle.fill")) + Text(
                        " This will call the APIs directly, which may not be allowed by GitHub. But it's used in other popular apps like Zed."
                    )
                }
                .dynamicHeightTextInFormWorkaround()
                .padding(.vertical)
            }.sheet(isPresented: $isEditingCustomHeader) {
                CustomHeaderSettingsView(headers: $store.customHeaders)
            }
        }
    }
}

class EmbeddingModelManagementView_Editing_Previews: PreviewProvider {
    static var previews: some View {
        EmbeddingModelEditView(
            store: .init(
                initialState: EmbeddingModel(
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
                reducer: { EmbeddingModelEdit() }
            )
        )
    }
}

