import AIModel
import ComposableArchitecture
import Preferences
import SwiftUI

struct ChatModelManagementView: View {
    let store: StoreOf<ChatModelManagement>

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Add Model") {
                    store.send(.createModel)
                }
            }.padding(4)

            ModelList(store: store)
                .sheet(store: store.scope(
                    state: \.$editingModel,
                    action: ChatModelManagement.Action.chatModelItem
                )) { store in
                    EditingPanel(store: store)
                        .frame(minWidth: 400)
                }
        }
        .onAppear {
            store.send(.appear)
        }
    }

    @MainActor
    struct EditingPanel: View {
        let store: StoreOf<ChatModelEdit>

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

                        Button(action: { store.send(.saveButtonClicked) }) {
                            Text("Save")
                        }
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
                            }
                        }
                    },
                    label: { Text("Format") }
                )
                .pickerStyle(.segmented)
            }
        }

        func baseURLTextField(prompt: Text?) -> some View {
            WithViewStore(store, removeDuplicates: { $0.baseURL == $1.baseURL }) { viewStore in
                TextField("Base URL", text: viewStore.$baseURL, prompt: prompt)
            }
        }

        var supportsFunctionCallingToggle: some View {
            WithViewStore(
                store,
                removeDuplicates: { $0.supportsFunctionCalling == $1.supportsFunctionCalling }
            ) { viewStore in
                Toggle(
                    "Supports Function Calling",
                    isOn: viewStore.$supportsFunctionCalling
                )
            }
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
                        Text("Max Token (Including Reply)")
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
            HStack {
                WithViewStore(
                    store,
                    observe: {
                        APIKeyState(
                            apiKeyName: $0.$apiKeyName,
                            availableAPIKeys: $0.availableAPIKeys
                        )
                    }
                ) { viewStore in
                    Picker(
                        selection: viewStore.$apiKeyName,
                        content: {
                            Text("No API Key").tag("")
                            if viewStore.state.availableAPIKeys.isEmpty {
                                Text("No API key found, please add a new one →")
                            }
                            ForEach(viewStore.state.availableAPIKeys, id: \.self) { name in
                                Text(name).tag(name)
                            }

                        },
                        label: { Text("API Key") }
                    )
                }

                Button(action: { store.send(.createAPIKeyButtonClicked) }) {
                    Text(Image(systemName: "plus"))
                }
            }
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
            supportsFunctionCallingToggle
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
            supportsFunctionCallingToggle
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
            supportsFunctionCallingToggle
        }
    }

    struct ModelList: View {
        let store: StoreOf<ChatModelManagement>

        var body: some View {
            WithViewStore(store) { viewStore in
                List {
                    ForEach(viewStore.state.models) { model in
                        let isSelected = viewStore.state.editingModel?.id == model.id
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal")

                            Button(action: {
                                viewStore.send(.selectModel(id: model.id))
                            }) {
                                Cell(chatModel: model, isSelected: isSelected)

                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Duplicate") {
                                    store.send(.duplicateModel(id: model.id))
                                }
                                Button("Remove") {
                                    store.send(.removeModel(id: model.id))
                                }
                            }
                        }
                    }
                    .onMove(perform: { indices, newOffset in
                        viewStore.send(.moveModel(from: indices, to: newOffset))
                    })
                }
                .removeBackground()
                .listStyle(.plain)
                .listRowInsets(EdgeInsets())
            }
        }
    }

    struct Cell: View {
        let chatModel: ChatModel
        let isSelected: Bool
        @State var isHovered: Bool = false

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text({
                            switch chatModel.format {
                            case .openAI: return "OpenAI"
                            case .azureOpenAI: return "Azure OpenAI"
                            case .openAICompatible: return "OpenAI Compatible"
                            }
                        }() as String)
                            .foregroundColor(isSelected ? .white : .primary)
                            .font(.subheadline.bold())
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        isSelected
                                            ? .white.opacity(0.2)
                                            : Color.primary.opacity(0.1)
                                    )
                            }

                        Text(chatModel.name)
                            .font(.headline)
                    }

                    HStack(spacing: 4) {
                        Text(chatModel.info.modelName)

                        if !chatModel.info.baseURL.isEmpty {
                            Image(systemName: "line.diagonal")
                            Text(chatModel.info.baseURL)
                        }

                        Image(systemName: "line.diagonal")

                        Text("\(chatModel.info.maxTokens) tokens")

                        Image(systemName: "line.diagonal")

                        Text(
                            "function calling \(chatModel.info.supportsFunctionCalling ? Image(systemName: "checkmark.square") : Image(systemName: "xmark.square"))"
                        )
                    }
                    .font(.subheadline)
                    .opacity(0.7)
                    .padding(.leading, 2)
                }
                Spacer()
            }
            .onHover(perform: {
                isHovered = $0
            })
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill({
                        switch (isSelected, isHovered) {
                        case (true, _):
                            return Color.accentColor
                        case (_, true):
                            return Color.primary.opacity(0.1)
                        case (_, false):
                            return Color.clear
                        }
                    }() as Color)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .animation(.easeInOut(duration: 0.1), value: isSelected)
            .animation(.easeInOut(duration: 0.1), value: isHovered)
        }
    }
}

// MARK: - Previews

class ChatModelManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ChatModelManagementView(
            store: .init(
                initialState: .init(
                    models: IdentifiedArray<String, ChatModel>(uniqueElements: [
                        ChatModel(
                            id: "1",
                            name: "Test Model",
                            format: .openAI,
                            info: .init(
                                apiKeyName: "key",
                                baseURL: "google.com",
                                maxTokens: 3000,
                                supportsFunctionCalling: true,
                                modelName: "gpt-3.5-turbo"
                            )
                        ),
                        ChatModel(
                            id: "2",
                            name: "Test Model 2",
                            format: .azureOpenAI,
                            info: .init(
                                apiKeyName: "key",
                                baseURL: "apple.com",
                                maxTokens: 3000,
                                supportsFunctionCalling: false,
                                modelName: "gpt-3.5-turbo"
                            )
                        ),
                        ChatModel(
                            id: "3",
                            name: "Test Model 3",
                            format: .openAICompatible,
                            info: .init(
                                apiKeyName: "key",
                                baseURL: "apple.com",
                                maxTokens: 3000,
                                supportsFunctionCalling: false,
                                modelName: "gpt-3.5-turbo"
                            )
                        ),
                    ]),
                    editingModel: .init(
                        id: "3",
                        name: "Test Model 2",
                        format: .azureOpenAI,
                        apiKeyName: "key",
                        baseURL: "apple.com",
                        maxTokens: 3000,
                        supportsFunctionCalling: false,
                        modelName: "gpt-3.5-turbo"
                    )
                ),
                reducer: ChatModelManagement(
                    userDefaults: UserDefaults(suiteName: "ChatModelManagementView_Previews")!
                )
            )
        )
    }
}

class ChatModelManagementView_Editing_Previews: PreviewProvider {
    static var previews: some View {
        ChatModelManagementView.EditingPanel(
            store: .init(
                initialState: .init(
                    id: "1",
                    name: "Test Model",
                    format: .openAI,
                    apiKeyName: "key",
                    baseURL: "google.com",
                    maxTokens: 3000,
                    supportsFunctionCalling: true,
                    modelName: "gpt-3.5-turbo"

                ),
                reducer: ChatModelEdit()
            )
        )
    }
}

class ChatModelManagementView_Cell_Previews: PreviewProvider {
    static var previews: some View {
        ChatModelManagementView.Cell(chatModel: .init(
            id: "1",
            name: "Test Model",
            format: .openAI,
            info: .init(
                apiKeyName: "key",
                baseURL: "google.com",
                maxTokens: 3000,
                supportsFunctionCalling: true,
                modelName: "gpt-3.5-turbo"
            )
        ), isSelected: false)
    }
}

