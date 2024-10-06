import ComposableArchitecture
import Foundation
import SwiftUI

/// The information of a tab.
@ObservableState
public struct ChatTabInfo: Identifiable, Equatable {
    public var id: String
    public var title: String
    public var focusTrigger: Int = 0

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// Every chat tab should conform to this type.
public typealias ChatTab = BaseChatTab & ChatTabType

/// Defines a bunch of things a chat tab should implement.
public protocol ChatTabType {
    /// Build the view for this chat tab.
    @ViewBuilder
    func buildView() -> any View
    /// Build the tabItem for this chat tab.
    @ViewBuilder
    func buildTabItem() -> any View
    /// Build the icon for this chat tab.
    @ViewBuilder
    func buildIcon() -> any View
    /// Build the menu for this chat tab.
    @ViewBuilder
    func buildMenu() -> any View
    /// The name of this chat tab type.
    static var name: String { get }
    /// Available builders for this chat tab.
    /// It's used to generate a list of tab types for user to create.
    static func chatBuilders() -> [ChatTabBuilder]
    /// Restorable state
    func restorableState() async -> Data
    /// Restore state
    static func restore(from data: Data) async throws -> any ChatTabBuilder
    /// Whenever the body or menu is accessed, this method will be called.
    /// It will be called only once so long as you don't call it yourself.
    /// It will be called from MainActor.
    func start()
}

/// The base class for all chat tabs.
open class BaseChatTab {
    /// A wrapper to support dynamic update of title in view.
    struct ContentView: View {
        var buildView: () -> any View
        var body: some View {
            AnyView(buildView())
        }
    }

    public var id: String = ""
    public var title: String = ""
    /// The store for chat tab info. You should only access it after `start` is called.
    public let chatTabStore: StoreOf<ChatTabItem>

    private var didStart = false
    private let storeObserver = NSObject()

    public init(store: StoreOf<ChatTabItem>) {
        chatTabStore = store

        Task { @MainActor in
            self.id = store.id
            self.title = store.title

            storeObserver.observe { [weak self] in
                guard let self else { return }
                self.title = store.title
                self.id = store.id
            }
        }
    }

    /// The view for this chat tab.
    @ViewBuilder
    public var body: some View {
        let id = "ChatTabBody\(id)"
        if let tab = self as? (any ChatTabType) {
            ContentView(buildView: tab.buildView).id(id)
                .onAppear {
                    Task { @MainActor in self.startIfNotStarted() }
                }
        } else {
            EmptyView().id(id)
        }
    }

    /// The tab item for this chat tab.
    @ViewBuilder
    public var tabItem: some View {
        let id = "ChatTabTab\(id)"
        if let tab = self as? (any ChatTabType) {
            ContentView(buildView: tab.buildTabItem).id(id)
                .onAppear {
                    Task { @MainActor in self.startIfNotStarted() }
                }
        } else {
            EmptyView().id(id)
        }
    }

    /// The icon for this chat tab.
    @ViewBuilder
    public var icon: some View {
        let id = "ChatTabIcon\(id)"
        if let tab = self as? (any ChatTabType) {
            ContentView(buildView: tab.buildIcon).id(id)
        } else {
            EmptyView().id(id)
        }
    }

    /// The tab item for this chat tab.
    @ViewBuilder
    public var menu: some View {
        let id = "ChatTabMenu\(id)"
        if let tab = self as? (any ChatTabType) {
            ContentView(buildView: tab.buildMenu).id(id)
                .onAppear {
                    Task { @MainActor in self.startIfNotStarted() }
                }
        } else {
            EmptyView().id(id)
        }
    }

    @MainActor
    func startIfNotStarted() {
        guard !didStart else { return }
        didStart = true

        if let tab = self as? (any ChatTabType) {
            tab.start()
        }
    }
}

/// A factory of a chat tab.
public protocol ChatTabBuilder {
    /// A visible title for user.
    var title: String { get }
    /// Build the chat tab.
    func build(store: StoreOf<ChatTabItem>) async -> (any ChatTab)?
}

/// A chat tab builder that doesn't build.
public struct DisabledChatTabBuilder: ChatTabBuilder {
    public var title: String
    public func build(store: StoreOf<ChatTabItem>) async -> (any ChatTab)? {
        return nil
    }

    public init(title: String) {
        self.title = title
    }
}

public extension ChatTabType {
    /// The name of this chat tab type.
    var name: String { Self.name }
}

/// A chat tab that does nothing.
public class EmptyChatTab: ChatTab {
    public static var name: String { "Empty" }

    struct Builder: ChatTabBuilder {
        let title: String
        func build(store: StoreOf<ChatTabItem>) async -> (any ChatTab)? {
            EmptyChatTab(store: store)
        }
    }

    public static func chatBuilders() -> [ChatTabBuilder] {
        [Builder(title: "Empty")]
    }

    public func buildView() -> any View {
        VStack {
            Text("Empty-\(id)")
        }
        .background(Color.blue)
    }

    public func buildTabItem() -> any View {
        Text("Empty-\(id)")
    }

    public func buildIcon() -> any View {
        Image(systemName: "square")
    }

    public func buildMenu() -> any View {
        Text("Empty-\(id)")
    }

    public func restorableState() async -> Data {
        return Data()
    }

    public static func restore(from data: Data) async throws -> any ChatTabBuilder {
        return Builder(title: "Empty")
    }

    public convenience init(id: String) {
        self.init(store: .init(
            initialState: .init(id: id, title: "Empty-\(id)"),
            reducer: { ChatTabItem() }
        ))
    }

    public func start() {
        chatTabStore.send(.updateTitle("Empty-\(id)"))
    }
}

