import AIModel
import ComposableArchitecture
import SwiftUI

struct EmbeddingModelManagementView: View {
    @Perception.Bindable var store: StoreOf<EmbeddingModelManagement>

    var body: some View {
        WithPerceptionTracking {
            AIModelManagementView<EmbeddingModelManagement, _>(store: store)
                .sheet(item: $store.scope(
                    state: \.editingModel,
                    action: \.embeddingModelItem
                )) { store in
                    EmbeddingModelEditView(store: store)
                        .frame(width: 800)
                }
        }
    }
}

// MARK: - Previews

class EmbeddingModelManagementView_Previews: PreviewProvider {
    static var previews: some View {
        EmbeddingModelManagementView(
            store: .init(
                initialState: .init(
                    models: IdentifiedArray<String, EmbeddingModel>(uniqueElements: [
                        EmbeddingModel(
                            id: "1",
                            name: "Test Model",
                            format: .openAI,
                            info: .init(
                                apiKeyName: "key",
                                baseURL: "google.com",
                                maxTokens: 3000,
                                modelName: "gpt-3.5-turbo"
                            )
                        ),
                        EmbeddingModel(
                            id: "2",
                            name: "Test Model 2",
                            format: .azureOpenAI,
                            info: .init(
                                apiKeyName: "key",
                                baseURL: "apple.com",
                                maxTokens: 3000,
                                modelName: "gpt-3.5-turbo"
                            )
                        ),
                        EmbeddingModel(
                            id: "3",
                            name: "Test Model 3",
                            format: .openAICompatible,
                            info: .init(
                                apiKeyName: "key",
                                baseURL: "apple.com",
                                maxTokens: 3000,
                                modelName: "gpt-3.5-turbo"
                            )
                        ),
                    ]),
                    editingModel: EmbeddingModel(
                        id: "3",
                        name: "Test Model 3",
                        format: .openAICompatible,
                        info: .init(
                            apiKeyName: "key",
                            baseURL: "apple.com",
                            maxTokens: 3000,
                            modelName: "gpt-3.5-turbo"
                        )
                    ).toState()
                ),
                reducer: { EmbeddingModelManagement() }
            )
        )
    }
}

