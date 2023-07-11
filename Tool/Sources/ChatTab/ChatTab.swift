import ComposableArchitecture
import Foundation
import SwiftUI

public struct ChatTabInfo: Identifiable, Equatable {
    public var id: String
    public var title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct ChatTabInfoPreferenceKey: PreferenceKey {
    public static var defaultValue: [ChatTabInfo] = []
    public static func reduce(value: inout [ChatTabInfo], nextValue: () -> [ChatTabInfo]) {
        value.append(contentsOf: nextValue())
    }
}

/// Every chat tab should conform to this type.
public typealias ChatTab = BaseChatTab & ChatTabType

/// The base class for all chat tabs.
open class BaseChatTab: Equatable {
    /// To support dynamic update of title in view.
    final class InfoObservable: ObservableObject {
        @Published var id: String
        @Published var title: String
        init(id: String, title: String) {
            self.title = title
            self.id = id
        }
    }

    /// A wrapper to support dynamic update of title in view.
    struct ContentView: View {
        @ObservedObject var info: InfoObservable
        var buildView: () -> any View
        var body: some View {
            AnyView(buildView())
                .preference(
                    key: ChatTabInfoPreferenceKey.self,
                    value: [ChatTabInfo(
                        id: info.id,
                        title: info.title
                    )]
                )
        }
    }

    public let id: String
    public var title: String {
        didSet { info.title = title }
    }

    let info: InfoObservable

    public init(id: String, title: String) {
        self.id = id
        self.title = title
        info = InfoObservable(id: id, title: title)
    }

    /// The view for this chat tab.
    @ViewBuilder
    public var body: some View {
        let id = "ChatTabBody\(info.id)"
        if let tab = self as? (any ChatTabType) {
            ContentView(info: info, buildView: tab.buildView).id(id)
        } else {
            EmptyView().id(id)
        }
    }

    /// The menu for this chat tab.
    @ViewBuilder
    public var menu: some View {
        let id = "ChatTabMenu\(info.id)"
        if let tab = self as? (any ChatTabType) {
            ContentView(info: info, buildView: tab.buildMenu).id(id)
        } else {
            EmptyView().id(id)
        }
    }

    public static func == (lhs: BaseChatTab, rhs: BaseChatTab) -> Bool {
        lhs.id == rhs.id
    }
}

/// A factory of a chat tab.
public protocol ChatTabBuilder {
    /// A visible title for user.
    var title: String { get }
    /// Build the chat tab.
    func build() -> any ChatTab
}

public protocol ChatTabType {
    /// The type of the external dependency required by this chat tab.
    associatedtype ExternalDependency
    /// Build the view for this chat tab.
    @ViewBuilder
    func buildView() -> any View
    /// Build the menu for this chat tab.
    @ViewBuilder
    func buildMenu() -> any View
    /// The name of this chat tab.
    static var name: String { get }
    /// Available builders for this chat tab.
    /// It's used to generate a list of tab types for user to create.
    static func chatBuilders(externalDependency: ExternalDependency) -> [ChatTabBuilder]
}

public extension ChatTabType where ExternalDependency == Void {
    /// Available builders for this chat tab.
    /// It's used to generate a list of tab types for user to create.
    static func chatBuilders() -> [ChatTabBuilder] {
        chatBuilders(externalDependency: ())
    }
}

public class EmptyChatTab: ChatTab {
    public static var name: String { "Empty" }

    struct Builder: ChatTabBuilder {
        let title: String
        func build() -> any ChatTab {
            EmptyChatTab()
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

    public init(id: String = UUID().uuidString) {
        super.init(id: id, title: "Empty")
    }
}

