import ComposableArchitecture
import Foundation
import Preferences
import WebKit
import Workspace
import XcodeInspector

@Reducer
struct CodeiumChatBrowser {
    @ObservableState
    struct State: Equatable {
        var loadingProgress: Double = 0
        var isLoading = false
        var title = "Codeium Chat"
        var error: String?
        var url: URL?
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)

        case initialize
        case loadCurrentWorkspace
        case reload
        case presentError(String)
        case removeError

        case observeTitleChange
        case updateTitle(String)
        case observeURLChange
        case updateURL(URL?)
        case observeIsLoading
        case updateIsLoading(Double)
    }

    let webView: WKWebView
    let uuid = UUID()

    private enum CancelID: Hashable {
        case observeTitleChange(UUID)
        case observeURLChange(UUID)
        case observeIsLoading(UUID)
    }

    @Dependency(\.workspacePool) var workspacePool

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .initialize:
                return .merge(
                    .run { send in await send(.observeTitleChange) },
                    .run { send in await send(.observeURLChange) },
                    .run { send in await send(.observeIsLoading) }
                )

            case .loadCurrentWorkspace:
                return .run { send in
                    guard let workspaceURL = await XcodeInspector.shared.safe.activeWorkspaceURL
                    else {
                        await send(.presentError("Can't find workspace."))
                        return
                    }
                    do {
                        let workspace = try await workspacePool
                            .fetchOrCreateWorkspace(workspaceURL: workspaceURL)
                        let codeiumPlugin = workspace.plugin(for: CodeiumWorkspacePlugin.self)
                        guard let service = await codeiumPlugin?.codeiumService
                        else {
                            await send(.presentError("Can't start service."))
                            return
                        }
                        let url = try await service.getChatURL()
                        await send(.removeError)
                        await webView.load(URLRequest(url: url))
                    } catch {
                        await send(.presentError(error.localizedDescription))
                    }
                }

            case .reload:
                webView.reload()
                return .none
                
            case .removeError:
                state.error = nil
                return .none
                
            case let .presentError(error):
                state.error = error
                return .none

            // MARK: Observation

            case .observeTitleChange:
                let stream = AsyncStream<String> { continuation in
                    let observation = webView.observe(\.title, options: [.new, .initial]) {
                        webView, _ in
                        continuation.yield(webView.title ?? "")
                    }

                    continuation.onTermination = { _ in
                        observation.invalidate()
                    }
                }

                return .run { send in
                    for await title in stream where !title.isEmpty {
                        try Task.checkCancellation()
                        await send(.updateTitle(title))
                    }
                }
                .cancellable(id: CancelID.observeTitleChange(uuid), cancelInFlight: true)

            case let .updateTitle(title):
                state.title = title
                return .none

            case .observeURLChange:
                let stream = AsyncStream<URL?> { continuation in
                    let observation = webView.observe(\.url, options: [.new, .initial]) {
                        _, url in
                        if let it = url.newValue {
                            continuation.yield(it)
                        }
                    }

                    continuation.onTermination = { _ in
                        observation.invalidate()
                    }
                }

                return .run { send in
                    for await url in stream {
                        try Task.checkCancellation()
                        await send(.updateURL(url))
                    }
                }.cancellable(id: CancelID.observeURLChange(uuid), cancelInFlight: true)

            case let .updateURL(url):
                state.url = url
                return .none

            case .observeIsLoading:
                let stream = AsyncStream<Double> { continuation in
                    let observation = webView
                        .observe(\.estimatedProgress, options: [.new]) { _, estimatedProgress in
                            if let it = estimatedProgress.newValue {
                                continuation.yield(it)
                            }
                        }

                    continuation.onTermination = { _ in
                        observation.invalidate()
                    }
                }

                return .run { send in
                    for await isLoading in stream {
                        try Task.checkCancellation()
                        await send(.updateIsLoading(isLoading))
                    }
                }.cancellable(id: CancelID.observeIsLoading(uuid), cancelInFlight: true)

            case let .updateIsLoading(progress):
                state.isLoading = progress != 1
                state.loadingProgress = progress
                return .none
            }
        }
    }
}

