import Dependencies
import Foundation
import SwiftUI

public final class ExternalTabContainer {
    public static var tabContainers = [String: ExternalTabContainer]()

    public struct TabItem: Identifiable {
        public var id: String
        public var title: String
        public var image: String
        public let viewBuilder: () -> AnyView

        public init<V: View>(
            id: String,
            title: String,
            image: String = "",
            @ViewBuilder viewBuilder: @escaping () -> V
        ) {
            self.id = id
            self.title = title
            self.image = image
            self.viewBuilder = { AnyView(viewBuilder()) }
        }
    }

    public var tabs: [TabItem] = []
    public init() { tabs = [] }

    public static func tabContainer(for id: String) -> ExternalTabContainer {
        if let tabContainer = tabContainers[id] {
            return tabContainer
        }
        let tabContainer = ExternalTabContainer()
        tabContainers[id] = tabContainer
        return tabContainer
    }

    @ViewBuilder
    public func tabView(for id: String) -> some View {
        if let tab = tabs.first(where: { $0.id == id }) {
            tab.viewBuilder()
        }
    }

    public func registerTab<V: View>(
        id: String,
        title: String,
        image: String = "",
        @ViewBuilder viewBuilder: @escaping () -> V
    ) {
        tabs.append(TabItem(id: id, title: title, image: image, viewBuilder: viewBuilder))
    }

    public static func registerTab<V: View>(
        for tabContainerId: String,
        id: String,
        title: String,
        image: String = "",
        @ViewBuilder viewBuilder: @escaping () -> V
    ) {
        tabContainer(for: tabContainerId).registerTab(
            id: id,
            title: title,
            image: image,
            viewBuilder: viewBuilder
        )
    }
}

