import Dependencies
import Foundation
import GitHubCopilotService
import Perception
import SwiftUI
import Toast

public struct GitHubCopilotModelPicker: View {
    @Perceptible
    final class ViewModel {
        var availableModels: [GitHubCopilotLLMModel] = []
        @PerceptionIgnored @Dependency(\.toast) var toast

        init() {}

        func appear() {
            reloadAvailableModels()
        }

        func disappear() {}

        func reloadAvailableModels() {
            Task { @MainActor in
                do {
                    availableModels = try await GitHubCopilotExtension.fetchLLMModels()
                } catch {
                    toast("Failed to fetch GitHub Copilot models: \(error)", .error)
                }
            }
        }
    }

    let title: String
    let hasDefaultModel: Bool
    @Binding var gitHubCopilotModelId: String
    @State var viewModel: ViewModel

    init(
        title: String,
        hasDefaultModel: Bool = true,
        gitHubCopilotModelId: Binding<String>
    ) {
        self.title = title
        _gitHubCopilotModelId = gitHubCopilotModelId
        self.hasDefaultModel = hasDefaultModel
        viewModel = .init()
    }

    public var body: some View {
        WithPerceptionTracking {
            TextField(title, text: $gitHubCopilotModelId)
                .overlay(alignment: .trailing) {
                    Picker(
                        "",
                        selection: $gitHubCopilotModelId,
                        content: {
                            if hasDefaultModel {
                                Text("Default").tag("")
                            }

                            if !gitHubCopilotModelId.isEmpty,
                               !viewModel.availableModels.contains(where: {
                                   $0.modelId == gitHubCopilotModelId
                               })
                            {
                                Text(gitHubCopilotModelId).tag(gitHubCopilotModelId)
                            }
                            if viewModel.availableModels.isEmpty {
                                Text({
                                    viewModel.reloadAvailableModels()
                                    return "Loading..."
                                }()).tag("Loading...")
                            }
                            ForEach(viewModel.availableModels) { model in
                                Text(model.modelId)
                                    .tag(model.modelId)
                            }
                        }
                    )
                    .frame(width: 20)
                }
                .onAppear {
                    viewModel.appear()
                }
                .onDisappear {
                    viewModel.disappear()
                }
        }
    }
}

