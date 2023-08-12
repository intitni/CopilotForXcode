import ComposableArchitecture
import Foundation
import SwiftUI

/// The information of a tab.
public struct ChatTabInfo: Identifiable, Equatable {
    public var id: String
    public var title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// Every chat tab should conform to this type.
public typealias ChatTab = BaseChatTab & ChatTabType

/// Defines a bunch of things a chat tab should implement.
public protocol ChatTabType {
    /// The type of the external dependency required by this chat tab.
    associatedtype ExternalDependency
    /// Build the view for this chat tab.
    @ViewBuilder
    func buildView() -> any View
    /// Build the menu for this chat tab.
    @ViewBuilder
    func buildMenu() -> any View
    /// The name of this chat tab type.
    static var name: String { get }
    /// Available builders for this chat tab.
    /// It's used to generate a list of tab types for user to create.
    static func chatBuilders(externalDependency: ExternalDependency) -> [ChatTabBuilder]
    /// Restorable state
    func restorableState() async -> Data
    /// Restore state
    static func restore(
        from data: Data,
        store: StoreOf<ChatTabItem>,
        externalDependency: ExternalDependency
    ) async throws -> any ChatTab
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

    public var id: String { chatTabViewStore.id }
    public var title: String { chatTabViewStore.title }
    public let chatTabStore: StoreOf<ChatTabItem>
    public let chatTabViewStore: ViewStoreOf<ChatTabItem>
    private var didStart = false

    public init(store: StoreOf<ChatTabItem>) {
        chatTabStore = store
        chatTabViewStore = ViewStore(store)
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

    /// The menu for this chat tab.
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
    /// whether the chat tab is buildable.
    var buildable: Bool { get }
    /// Build the chat tab.
    func build(store: StoreOf<ChatTabItem>) -> any ChatTab
}

/// A chat tab builder that doesn't build.
public struct DisabledChatTabBuilder: ChatTabBuilder {
    public var title: String
    public var buildable: Bool { false }
    public func build(store: StoreOf<ChatTabItem>) -> any ChatTab {
        EmptyChatTab(store: store)
    }

    public init(title: String) {
        self.title = title
    }
}

public extension ChatTabType {
    /// The name of this chat tab type.
    var name: String { Self.name }
}

public extension ChatTabType where ExternalDependency == Void {
    /// Available builders for this chat tab.
    /// It's used to generate a list of tab types for user to create.
    static func chatBuilders() -> [ChatTabBuilder] {
        chatBuilders(externalDependency: ())
    }
}

/// A chat tab that does nothing.
public class EmptyChatTab: ChatTab {
    public static var name: String { "Empty" }

    struct Builder: ChatTabBuilder {
        let title: String
        var buildable: Bool { true }
        func build(store: StoreOf<ChatTabItem>) -> any ChatTab {
            EmptyChatTab(store: store)
        }
    }

    public static func chatBuilders(externalDependency: Void) -> [ChatTabBuilder] {
        [Builder(title: "Empty")]
    }

    public func buildView() -> any View {
        VStack {
            Text("Empty-\(id)")
        }
        .background(Color.blue)
    }

    public func buildMenu() -> any View {
        EmptyView()
    }

    public func restorableState() async -> Data {
        return Data()
    }

    public static func restore(
        from data: Data,
        store: StoreOf<ChatTabItem>,
        externalDependency: Void
    ) async throws -> any ChatTab {
        return Builder(title: "Empty").build(store: store)
    }

    public convenience init(id: String) {
        self.init(store: .init(
            initialState: .init(id: id, title: "Empty-\(id)"),
            reducer: ChatTabItem()
        ))
    }

    public func start() {
        chatTabViewStore.send(.updateTitle("Empty-\(id)"))
    }
}

