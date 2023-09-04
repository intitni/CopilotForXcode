import AIModel
import ComposableArchitecture
import SwiftUI

protocol AIModelManagementAction {
    associatedtype Model: ManageableAIModel
    static var appear: Self { get }
    static var createModel: Self { get }
    static func removeModel(id: Model.ID) -> Self
    static func selectModel(id: Model.ID) -> Self
    static func duplicateModel(id: Model.ID) -> Self
    static func moveModel(from: IndexSet, to: Int) -> Self
}

protocol AIModelManagementState: Equatable {
    associatedtype Model: ManageableAIModel
    var models: IdentifiedArrayOf<Model> { get }
    var selectedModelId: Model.ID? { get }
}

protocol AIModelManagement: ReducerProtocol where
    Action: AIModelManagementAction,
    State: AIModelManagementState,
    Action.Model == Self.Model,
    State.Model == Self.Model
{
    associatedtype Model: ManageableAIModel
}

protocol ManageableAIModel: Identifiable {
    associatedtype V: View
    var name: String { get }
    var formatName: String { get }
    var infoDescriptors: V { get }
}

struct AIModelManagementView<Management: AIModelManagement, Model: ManageableAIModel>: View
    where Management.Model == Model
{
    let store: StoreOf<Management>

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Add Model") {
                    store.send(.createModel)
                }
            }.padding(4)
            
            Divider()

            ModelList(store: store)
        }
        .onAppear {
            store.send(.appear)
        }
    }

    struct ModelList: View {
        let store: StoreOf<Management>

        var body: some View {
            WithViewStore(store) { viewStore in
                List {
                    ForEach(viewStore.state.models) { model in
                        let isSelected = viewStore.state.selectedModelId == model.id
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal")

                            Button(action: {
                                viewStore.send(.selectModel(id: model.id))
                            }) {
                                Cell(model: model, isSelected: isSelected)
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
        let model: Model
        let isSelected: Bool
        @State var isHovered: Bool = false

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(model.formatName)
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

                        Text(model.name)
                            .font(.headline)
                    }

                    HStack(spacing: 4) {
                        model.infoDescriptors
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

 class AIModelManagement_Previews: PreviewProvider {
     static var previews: some View {
         AIModelManagementView<ChatModelManagement, _>(
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
                         model: ChatModel(
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
                         )
                     )
                 ),
                 reducer: ChatModelManagement()
             )
         )
     }
 }


 class AIModelManagement_Cell_Previews: PreviewProvider {
    static var previews: some View {
        AIModelManagementView<ChatModelManagement, ChatModel>.Cell(model: ChatModel(
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


