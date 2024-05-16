import AIModel
import ComposableArchitecture
import SwiftUI

struct ChatModelManagementView: View {
    @Perception.Bindable var store: StoreOf<ChatModelManagement>

    var body: some View {
        WithPerceptionTracking {
            AIModelManagementView<ChatModelManagement, ChatModelManagement.Model>(store: store)
                .sheet(item: $store.scope(
                    state: \.editingModel,
                    action: \.chatModelItem
                )) { store in
                    ChatModelEditView(store: store)
                        .frame(width: 800)
                }
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
                    editingModel: ChatModel(
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
                    ).toState()
                ),
                reducer: { ChatModelManagement() }
            )
        )
    }
}

