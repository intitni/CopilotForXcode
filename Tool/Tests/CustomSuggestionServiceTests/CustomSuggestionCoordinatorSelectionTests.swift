import AIModel
import CopilotForXcodeKit
import Foundation
import Preferences
import XCTest

@testable import CustomSuggestionService

final class CustomSuggestionCoordinatorSelectionTests: XCTestCase {
    func test_getModel_matching_chat_model() async throws {
        let coordinator = CustomSuggestionCoordinator()
        let chat = ChatModel(
            id: "chat-1",
            name: "GPT",
            format: .openAI,
            info: .init(modelName: "gpt-5.5")
        )
        let model = try await coordinator.getModel(.init(
            modelId: "chat-1",
            chatModels: [chat],
            strategyId: ""
        ))
        guard case let .chatModel(found) = model else {
            return XCTFail("expected chat model")
        }
        XCTAssertEqual(found.id, "chat-1")
    }

    func test_getModel_dangling_and_empty_id_throw() async {
        let coordinator = CustomSuggestionCoordinator()
        await assertModelMissing(
            coordinator,
            snapshot: .init(modelId: "dangling", chatModels: [], strategyId: ""),
            description: "Selected suggestion model \"dangling\" no longer exists. Pick one in Service › Custom Model."
        )
        await assertModelMissing(
            coordinator,
            snapshot: .init(modelId: "chatModel", chatModels: [], strategyId: ""),
            description: "Selected suggestion model \"chatModel\" no longer exists. Pick one in Service › Custom Model."
        )
        await assertModelMissing(
            coordinator,
            snapshot: .init(modelId: "", chatModels: [], strategyId: ""),
            description: "No suggestion model is selected. Pick one in Service › Custom Model."
        )
    }

    func test_getModel_custom_model_types() async throws {
        let coordinator = CustomSuggestionCoordinator()
        let completion = try await coordinator.getModel(.init(
            modelId: CustomModelType.completionModel.rawValue,
            chatModels: [],
            strategyId: ""
        ))
        guard case .completionModel = completion else {
            return XCTFail("expected completion model")
        }

        let tabby = try await coordinator.getModel(.init(
            modelId: CustomModelType.tabby.rawValue,
            chatModels: [],
            strategyId: ""
        ))
        guard case .tabbyModel = tabby else {
            return XCTFail("expected tabby model")
        }

        let fim = try await coordinator.getModel(.init(
            modelId: CustomModelType.fimModel.rawValue,
            chatModels: [],
            strategyId: ""
        ))
        guard case .fimModel = fim else {
            return XCTFail("expected FIM model")
        }
    }

    func test_getStrategy_routes_by_model_and_option() async {
        let coordinator = CustomSuggestionCoordinator()
        let request = suggestionRequest()

        let tabby = await coordinator.getStrategy(
            sourceRequest: request,
            prefix: ["let x = "],
            suffix: [],
            snapshot: .init(
                modelId: CustomModelType.tabby.rawValue,
                chatModels: [],
                strategyId: RequestStrategyOption.naive.rawValue
            )
        )
        XCTAssertTrue(tabby is TabbyRequestStrategy)

        let fim = await coordinator.getStrategy(
            sourceRequest: request,
            prefix: ["let x = "],
            suffix: [],
            snapshot: .init(
                modelId: CustomModelType.fimModel.rawValue,
                chatModels: [],
                strategyId: ""
            )
        )
        XCTAssertTrue(fim is FIMEndpointRequestStrategy)

        let defaultStrategy = await coordinator.getStrategy(
            sourceRequest: request,
            prefix: ["let x = "],
            suffix: [],
            snapshot: .init(modelId: "chat-1", chatModels: [], strategyId: "")
        )
        XCTAssertTrue(defaultStrategy is DefaultRequestStrategy)

        let naive = await coordinator.getStrategy(
            sourceRequest: request,
            prefix: ["let x = "],
            suffix: [],
            snapshot: .init(
                modelId: "chat-1",
                chatModels: [],
                strategyId: RequestStrategyOption.naive.rawValue
            )
        )
        XCTAssertTrue(naive is NaiveRequestStrategy)

        let unknown = await coordinator.getStrategy(
            sourceRequest: request,
            prefix: ["let x = "],
            suffix: [],
            snapshot: .init(modelId: "chat-1", chatModels: [], strategyId: "not-a-strategy")
        )
        XCTAssertTrue(unknown is DefaultRequestStrategy)
    }
}

private func assertModelMissing(
    _ coordinator: CustomSuggestionCoordinator,
    snapshot: CustomSuggestionCoordinator.PreferenceSnapshot,
    description: String
) async {
    do {
        _ = try await coordinator.getModel(snapshot)
        XCTFail("expected SelectionError")
    } catch let error as CustomSuggestionCoordinator.SelectionError {
        XCTAssertEqual(error.localizedDescription, description)
    } catch {
        XCTFail("unexpected \(error)")
    }
}

private func suggestionRequest() -> SuggestionRequest {
    SuggestionRequest(
        fileURL: URL(fileURLWithPath: "/tmp/a.swift"),
        relativePath: "a.swift",
        language: CodeLanguage(rawValue: "swift") ?? .plaintext,
        content: "let x = ",
        originalContent: "let x = ",
        cursorPosition: .init(line: 0, character: 8),
        tabSize: 4,
        indentSize: 4,
        usesTabsForIndentation: false,
        relevantCodeSnippets: []
    )
}
