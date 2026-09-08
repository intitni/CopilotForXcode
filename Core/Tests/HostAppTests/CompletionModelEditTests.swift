import AIModel
import ComposableArchitecture
import Foundation
import Preferences
import Toast
import XCTest

@testable import HostApp

@MainActor
final class CompletionModelEditTests: XCTestCase {
    func test_saveButtonClicked_emptyModelName_doesNotWrite() async {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = TestStore(
            initialState: CompletionModelEdit.State(
                format: .openAI,
                modelName: "  ",
                baseURLSelection: .init(baseURL: "https://api.openai.com")
            )
        ) {
            CompletionModelEdit()
        } withDependencies: {
            $0.userDefaults = defaults
            $0.toastController = ToastController(messages: [])
        }

        await store.send(.saveButtonClicked)
        XCTAssertNil(
            defaults.value(forKey: UserDefaultPreferenceKeys().customSuggestionCompletionModel.key)
        )
        XCTAssertFalse(store.state.didSave)
    }

    func test_saveButtonClicked_emptyBaseURL_doesNotWrite() async {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = TestStore(
            initialState: CompletionModelEdit.State(
                format: .openAI,
                modelName: "gpt-3.5-turbo-instruct",
                baseURLSelection: .init(baseURL: "")
            )
        ) {
            CompletionModelEdit()
        } withDependencies: {
            $0.userDefaults = defaults
            $0.toastController = ToastController(messages: [])
        }

        await store.send(.saveButtonClicked)
        XCTAssertNil(
            defaults.value(forKey: UserDefaultPreferenceKeys().customSuggestionCompletionModel.key)
        )
        XCTAssertFalse(store.state.didSave)
    }

    func test_saveButtonClicked_writesViaUserDefaults() async {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = TestStore(
            initialState: CompletionModelEdit.State(
                id: "custom-id",
                format: .openAI,
                maxTokens: 2048,
                modelName: "gpt-3.5-turbo-instruct",
                baseURLSelection: .init(baseURL: "https://api.openai.com")
            )
        ) {
            CompletionModelEdit()
        } withDependencies: {
            $0.userDefaults = defaults
            $0.toastController = ToastController(messages: [])
        }

        await store.send(.saveButtonClicked) {
            $0.didSave = true
        }

        let saved = defaults.value(for: \.customSuggestionCompletionModel)
        XCTAssertEqual(saved.id, "custom-id")
        XCTAssertEqual(saved.info.modelName, "gpt-3.5-turbo-instruct")
        XCTAssertEqual(saved.info.baseURL, "https://api.openai.com")
        XCTAssertEqual(saved.info.maxTokens, 2048)
        XCTAssertEqual(saved.format, .openAI)
    }
}

private func isolatedDefaults() -> (UserDefaults, String) {
    let suite = "CompletionModelEditTests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return (defaults, suite)
}
