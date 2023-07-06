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

open class BaseChatTab: Equatable {
    final class InfoObservable: ObservableObject {
        @Published var id: String
        @Published var title: String
        init(id: String, title: String) {
            self.title = title
            self.id = id
        }
    }

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

    @ViewBuilder
    public var body: some View {
        if let tab = self as? ChatTabType {
            ContentView(info: info, buildView: tab.buildView).id(info.id)
        } else {
            EmptyView().id(info.id)
        }
    }

    public static func == (lhs: BaseChatTab, rhs: BaseChatTab) -> Bool {
        lhs.id == rhs.id
    }
}

public protocol ChatTabType {
    @ViewBuilder
    func buildView() -> any View
}

public class EmptyChatTab: ChatTab {
    public func buildView() -> any View {
        VStack {
            Text("Empty-\(id)")
        }
        .background(Color.blue)
    }

    public init(id: String = UUID().uuidString) {
        super.init(id: id, title: "Empty")
    }
}

