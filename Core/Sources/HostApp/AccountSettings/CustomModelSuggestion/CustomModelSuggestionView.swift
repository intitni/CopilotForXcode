import AIModel
import ComposableArchitecture
import CustomSuggestionService
import Preferences
import SwiftUI

struct CustomModelSuggestionView: View {
    final class Settings: ObservableObject {
        @AppStorage(\.customSuggestionModelId) var modelId
        @AppStorage(\.customSuggestionVerboseLog) var verboseLog
        @AppStorage(\.customSuggestionMaxLines) var maxLines
        @AppStorage(\.customSuggestionMaxGenerationToken) var maxGenerationToken
    }

    let store: StoreOf<CustomModelSuggestion>
    @StateObject var settings = Settings()
    @State var isEditingCustomModel = false

    var body: some View {
        WithPerceptionTracking {
            let modelType = CustomModelType(rawValue: settings.modelId)
            Form {
                Section {
                    HStack {
                        CustomModelPicker()
                        if modelType != nil {
                            Button("Edit Model") {
                                isEditingCustomModel = true
                            }
                        }
                    }

                    switch modelType {
                    case .completionModel, nil:
                        RequestStrategyPicker()
                    case .tabby, .fimModel:
                        EmptyView()
                    }

                    NumberInput(value: settings.$maxLines, range: 0...Int.max, step: 1) {
                        Text("Suggestion Line Limit (0 for unlimited)")
                    }

                    NumberInput(
                        value: settings.$maxGenerationToken,
                        range: 0...Int.max,
                        step: 100
                    ) {
                        Text("Suggestion Token Limit")
                    }
                } header: {
                    Text("Custom Model")
                } footer: {
                    Text(
                        "Generate suggestions with locally run or self-hosted models. Select \"Custom Model\" as the suggestion provider in Feature - Suggestion to use it."
                    )
                }

                if modelType == nil {
                    Section {
                        ChatAPIOptionsPicker()
                    } header: {
                        Text("Chat Model API")
                    } footer: {
                        Text(
                            "Applies to OpenAI and OpenAI compatible chat models. Setting a reasoning effort switches the request to the reasoning model shape: reasoning_effort is sent, max_completion_tokens replaces max_tokens, temperature and stop are omitted. Anthropic models always use /v1/messages."
                        )
                    }
                }

                Section {
                    Toggle("Verbose Log (Logs to Console.app)", isOn: settings.$verboseLog)
                }
            }
            .formStyle(.grouped)
            .sheet(isPresented: $isEditingCustomModel) {
                switch CustomModelType(rawValue: settings.modelId) {
                case .completionModel:
                    CompletionModelEditView(store: store.scope(
                        state: \.completionModel,
                        action: \.completionModel
                    ))
                    .frame(width: 800)
                case .fimModel:
                    FIMModelEditView(store: store.scope(
                        state: \.fimModel,
                        action: \.fimModel
                    ))
                    .frame(width: 800)
                case .tabby:
                    TabbyModelEditView(store: store.scope(
                        state: \.tabbyModel,
                        action: \.tabbyModel
                    ))
                    .frame(width: 800)
                case nil:
                    EmptyView()
                }
            }
        }
    }
}

/// Picks either a built-in custom model type or one of the chat models configured in the host.
struct CustomModelPicker: View {
    final class Settings: ObservableObject {
        @AppStorage(\.chatModels) var chatModels: [ChatModel]
        @AppStorage(\.customSuggestionModelId) var modelId: String
    }

    @StateObject var settings = Settings()

    var body: some View {
        let unknownId: String? =
            if !settings.chatModels.contains(where: { $0.id == settings.modelId }),
            !settings.modelId.isEmpty,
            CustomModelType(rawValue: settings.modelId) == nil
        {
            settings.modelId
        } else {
            nil
        }

        Picker(selection: settings.$modelId, label: Text("Model")) {
            if let unknownId {
                Text("Unknown Model (Use Custom Model Instead)").tag(unknownId)
            }

            ForEach(CustomModelType.allCases, id: \.rawValue) {
                switch $0 {
                case .completionModel:
                    Text("Custom Model (Completion API)").tag($0.rawValue)
                case .fimModel:
                    Text("Custom Model (FIM API)").tag($0.rawValue)
                case .tabby:
                    Text("Tabby").tag($0.rawValue)
                }
            }

            ForEach(settings.chatModels, id: \.id) { chatModel in
                Text(chatModel.name).tag(chatModel.id)
            }
        }
    }
}

struct RequestStrategyPicker: View {
    final class Settings: ObservableObject {
        @AppStorage(\.customSuggestionRequestStrategyId) var requestStrategyId
        @AppStorage(\.customSuggestionFIMTemplate) var fimTemplate
        @AppStorage(\.customSuggestionFIMPromptIsRaw) var fimPromptIsRaw
        @AppStorage(\.customSuggestionFIMStopToken) var fimStopToken
        @AppStorage(\.customSuggestionFIMAttachFileInfo) var fimAttachFileInfo
    }

    @StateObject var settings = Settings()

    var body: some View {
        let option = RequestStrategyOption(rawValue: settings.requestStrategyId)
        let unknownId: String? = option == nil ? settings.requestStrategyId : nil

        Picker(selection: settings.$requestStrategyId, label: Text("Request Strategy")) {
            if let unknownId {
                Text("Unknown Strategy (Use Default Strategy Instead)").tag(unknownId)
            }

            ForEach(RequestStrategyOption.allCases, id: \.rawValue) { option in
                switch option {
                case .default:
                    Text("Default").tag(option.rawValue)
                case .naive:
                    Text("Naive").tag(option.rawValue)
                case .continue:
                    Text("Continue").tag(option.rawValue)
                case .codeLlamaFillInTheMiddle:
                    Text("Fill-in-the-Middle (for models with FIM support, e.g. codellama:xb-code)")
                        .tag(option.rawValue)
                case .codeLlamaFillInTheMiddleWithSystemPrompt:
                    Text("Fill-in-the-Middle with System Prompt").tag(option.rawValue)
                case .anthropic:
                    Text("Anthropic Optimized").tag(option.rawValue)
                }
            }
        }

        if option == .codeLlamaFillInTheMiddle
            || option == .codeLlamaFillInTheMiddleWithSystemPrompt
        {
            TextField(
                text: $settings.fimTemplate,
                prompt: Text(UserDefaultPreferenceKeys().customSuggestionFIMTemplate.defaultValue)
            ) { Text("FIM Template") }
            Toggle(isOn: $settings.fimPromptIsRaw) { Text("Raw Prompt") }
            Toggle(isOn: $settings.fimAttachFileInfo) { Text("Attach File Info") }
            TextField(text: $settings.fimStopToken) { Text("FIM Stop Token") }
        }
    }
}

struct ChatAPIOptionsPicker: View {
    final class Settings: ObservableObject {
        @AppStorage(\.customSuggestionOpenAIAPI) var openAIAPI
        @AppStorage(\.customSuggestionReasoningEffort) var reasoningEffort
    }

    @StateObject var settings = Settings()

    var body: some View {
        Picker(selection: settings.$openAIAPI, label: Text("OpenAI Endpoint")) {
            ForEach(OpenAIChatAPI.allCases, id: \.rawValue) { api in
                switch api {
                case .chatCompletions:
                    Text("Chat Completions (/v1/chat/completions)").tag(api.rawValue)
                case .responses:
                    Text("Responses (/v1/responses)").tag(api.rawValue)
                }
            }
        }

        Picker(selection: settings.$reasoningEffort, label: Text("Reasoning Effort")) {
            Text("Not Set").tag("")
            ForEach(ReasoningEffort.allCases, id: \.rawValue) { effort in
                Text(effort.rawValue.capitalized).tag(effort.rawValue)
            }
        }
    }
}

private struct NumberInput<V: Strideable, Label: View>: View {
    @Binding var value: V
    let formatter = NumberFormatter()
    let range: ClosedRange<V>
    let step: V.Stride
    @ViewBuilder var label: () -> Label

    var body: some View {
        TextField(value: .init(get: {
            min(max(value, range.lowerBound), range.upperBound)
        }, set: { newValue in
            value = min(max(newValue, range.lowerBound), range.upperBound)
        }), formatter: formatter, prompt: nil) {
            label()
        }
        .padding(.trailing)
        .overlay(alignment: .trailing) {
            Stepper(value: $value, in: range, step: step) {
                EmptyView()
            }
        }
        .padding(.trailing, 4)
    }
}

#Preview {
    CustomModelSuggestionView(store: .init(initialState: .init(), reducer: { CustomModelSuggestion() }))
        .frame(width: 800, height: 600)
}
