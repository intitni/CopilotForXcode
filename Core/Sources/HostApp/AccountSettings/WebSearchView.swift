import AppKit
import Client
import ComposableArchitecture
import OpenAIService
import Preferences
import SuggestionBasic
import SwiftUI
import WebSearchService

@Reducer
struct WebSearchSettings {
    struct TestResult: Identifiable, Equatable {
        let id = UUID()
        var duration: TimeInterval
        var result: Result<WebSearchResult, Error>?

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }
    }

    @ObservableState
    struct State: Equatable {
        var apiKeySelection: APIKeySelection.State = .init()
        var testResult: TestResult?
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case appear
        case test
        case bringUpTestResult
        case updateTestResult(TimeInterval, Result<WebSearchResult, Error>)
        case apiKeySelection(APIKeySelection.Action)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.apiKeySelection, action: \.apiKeySelection) {
            APIKeySelection()
        }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .appear:
                state.testResult = nil
                state.apiKeySelection.apiKeyName = UserDefaults.shared.value(for: \.serpAPIKeyName)
                return .none
            case .test:
                return .run { send in
                    let searchService = WebSearchService(provider: .userPreferred)
                    await send(.bringUpTestResult)
                    let start = Date()
                    do {
                        let result = try await searchService.search(query: "Swift")
                        let duration = Date().timeIntervalSince(start)
                        await send(.updateTestResult(duration, .success(result)))
                    } catch {
                        let duration = Date().timeIntervalSince(start)
                        await send(.updateTestResult(duration, .failure(error)))
                    }
                }
            case .bringUpTestResult:
                state.testResult = .init(duration: 0)
                return .none
            case let .updateTestResult(duration, result):
                state.testResult?.duration = duration
                state.testResult?.result = result
                return .none
            case let .apiKeySelection(action):
                switch action {
                case .binding(\APIKeySelection.State.apiKeyName):
                    UserDefaults.shared.set(state.apiKeySelection.apiKeyName, for: \.serpAPIKeyName)
                    return .none
                default:
                    return .none
                }
            }
        }
    }
}

final class WebSearchViewSettings: ObservableObject {
    @AppStorage(\.serpAPIEngine) var serpAPIEngine
    @AppStorage(\.headlessBrowserEngine) var headlessBrowserEngine
    @AppStorage(\.searchProvider) var searchProvider
    init() {}
}

struct WebSearchView: View {
    @Perception.Bindable var store: StoreOf<WebSearchSettings>
    @Environment(\.openURL) var openURL
    @StateObject var settings = WebSearchViewSettings()

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                Form {
                    Section(header: Text("Search Provider")) {
                        Picker("Search Provider", selection: $settings.searchProvider) {
                            ForEach(UserDefaultPreferenceKeys.SearchProvider.allCases, id: \.self) {
                                provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    switch settings.searchProvider {
                    case .serpAPI:
                        serpAPIForm()
                    case .headlessBrowser:
                        headlessBrowserForm()
                    }

                    Section {
                        Button("Test Search") {
                            store.send(.test)
                        }
                    }
                }
                .padding()
            }
            .sheet(item: $store.testResult) { testResult in
                testResultView(testResult: testResult)
            }
            .onAppear {
                store.send(.appear)
            }
        }
    }

    @ViewBuilder
    func serpAPIForm() -> some View {
        Section(header: Text("SerpAPI")) {
            Picker("Engine", selection: $settings.serpAPIEngine) {
                ForEach(
                    UserDefaultPreferenceKeys.SerpAPIEngine.allCases,
                    id: \.self
                ) { engine in
                    Text(engine.rawValue).tag(engine)
                }
            }

            WithPerceptionTracking {
                APIKeyPicker(store: store.scope(
                    state: \.apiKeySelection,
                    action: \.apiKeySelection
                ))
            }
        }
    }

    @ViewBuilder
    func headlessBrowserForm() -> some View {
        Section(header: Text("Headless Browser")) {
            Picker("Engine", selection: $settings.headlessBrowserEngine) {
                ForEach(
                    UserDefaultPreferenceKeys.HeadlessBrowserEngine.allCases,
                    id: \.self
                ) { engine in
                    Text(engine.rawValue).tag(engine)
                }
            }
        }
    }

    @ViewBuilder
    func testResultView(testResult: WebSearchSettings.TestResult) -> some View {
        VStack {
            Text("Test Result")
                .font(.headline)
                .padding()

            if let result = testResult.result {
                switch result {
                case let .success(webSearchResult):
                    VStack(alignment: .leading) {
                        Text("Success (Completed in \(testResult.duration, specifier: "%.2f")s)")
                            .foregroundColor(.green)

                        Text("Found \(webSearchResult.webPages.count) results:")
                            .padding(.top)

                        ScrollView {
                            ForEach(webSearchResult.webPages, id: \.urlString) { page in
                                VStack(alignment: .leading) {
                                    Text(page.title)
                                        .font(.headline)
                                    Text(page.urlString)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text(page.snippet)
                                        .padding(.top, 2)
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                    }
                    .padding()
                case let .failure(error):
                    VStack(alignment: .leading) {
                        Text("Error (Completed in \(testResult.duration, specifier: "%.2f")s)")
                            .foregroundColor(.red)
                        Text(error.localizedDescription)
                            .padding(.top)
                    }
                    .padding()
                }
            } else {
                VStack {
                    ProgressView()
                }
                .padding()
            }

            Button("Close") {
                store.testResult = nil
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

// Helper struct to make TestResult identifiable for sheet presentation
private struct TestResultWrapper: Identifiable {
    var id: UUID = .init()
    var testResult: WebSearchSettings.TestResult
}

struct WebSearchView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            WebSearchView(store: .init(initialState: .init(), reducer: { WebSearchSettings() }))
        }
        .frame(height: 800)
        .padding(.all, 8)
    }
}

