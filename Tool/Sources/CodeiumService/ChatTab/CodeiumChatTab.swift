import AppKit
import ChatTab
import Combine
import ComposableArchitecture
import Logger
import Preferences
import SwiftUI
import WebKit
import XcodeInspector

public class CodeiumChatTab: ChatTab {
    public static var name: String { "Codeium Chat" }

    struct RestorableState: Codable {}

    public struct EditorContent {
        public var selectedText: String
        public var language: String
        public var fileContent: String

        public init(selectedText: String, language: String, fileContent: String) {
            self.selectedText = selectedText
            self.language = language
            self.fileContent = fileContent
        }

        public static var empty: EditorContent {
            .init(selectedText: "", language: "", fileContent: "")
        }
    }

    struct Builder: ChatTabBuilder {
        var title: String
        var buildable: Bool { true }
        var afterBuild: (CodeiumChatTab) async -> Void = { _ in }

        func build(store: StoreOf<ChatTabItem>) async -> (any ChatTab)? {
            let tab = await CodeiumChatTab(chatTabStore: store)
            await Task { @MainActor in
                _ = tab.store.send(.loadCurrentWorkspace)
            }.value
            await afterBuild(tab)
            return tab
        }
    }

    let store: StoreOf<CodeiumChatBrowser>
    let webView: WKWebView
    let webViewDelegate: WKWebViewDelegate
    var cancellable = Set<AnyCancellable>()
    private var observer = NSObject()

    @MainActor
    public init(chatTabStore: StoreOf<ChatTabItem>) {
        let webView = CodeiumWebView(getEditorContent: {
            guard let content = await XcodeInspector.shared.getFocusedEditorContent()
            else { return .empty }
            return .init(
                selectedText: content.selectedContent,
                language: content.language.rawValue,
                fileContent: content.editorContent?.content ?? ""
            )
        })
        self.webView = webView
        store = .init(
            initialState: .init(),
            reducer: { CodeiumChatBrowser(webView: webView) }
        )
        webViewDelegate = .init(store: store)

        super.init(store: chatTabStore)

        webView.navigationDelegate = webViewDelegate
        webView.uiDelegate = webViewDelegate
        webView.store = store

        Task {
            await CodeiumServiceLifeKeeper.shared.add(self)
        }
    }

    public func start() {
        observer = .init()
        cancellable = []
        chatTabStore.send(.updateTitle("Codeium Chat"))
        store.send(.initialize)

        do {
            var previousURL: URL?
            observer.observe { [weak self] in
                guard let self else { return }
                if store.url != previousURL {
                    previousURL = store.url
                    Task { @MainActor in
                        self.chatTabStore.send(.tabContentUpdated)
                    }
                }
            }
        }

        observer.observe { [weak self] in
            guard let self, !store.title.isEmpty else { return }
            let title = store.title
            Task { @MainActor in
                self.chatTabStore.send(.updateTitle(title))
            }
        }
    }

    public func buildView() -> any View {
        BrowserView(store: store, webView: webView)
    }

    public func buildTabItem() -> any View {
        CodeiumChatTabItem(store: store)
    }

    public func buildIcon() -> any View {
        Image(systemName: "message")
    }

    public func buildMenu() -> any View {
        EmptyView()
    }

    @MainActor
    public func restorableState() -> Data {
        let state = store.withState { _ in
            RestorableState()
        }

        return (try? JSONEncoder().encode(state)) ?? Data()
    }

    public static func restore(from data: Data) throws -> any ChatTabBuilder {
        let builder = Builder(title: "") { @MainActor chatTab in
            chatTab.store.send(.loadCurrentWorkspace)
        }
        return builder
    }

    public static func chatBuilders() -> [ChatTabBuilder] {
        [Builder(title: "Codeium Chat")]
    }

	public static func defaultChatBuilder() -> ChatTabBuilder {
        Builder(title: "Codeium Chat")
    }
}

