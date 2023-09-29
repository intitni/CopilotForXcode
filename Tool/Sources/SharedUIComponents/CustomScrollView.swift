import AppKit
import Combine
import Preferences
import SwiftUI

public struct CustomScrollViewHeightPreferenceKey: SwiftUI.PreferenceKey {
    public static var defaultValue: Double = 0
    public static func reduce(value: inout Double, nextValue: () -> Double) {
        value = nextValue() + value
    }
}

public struct CustomScrollViewUpdateHeightModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: CustomScrollViewHeightPreferenceKey.self,
                            value: proxy.size.height
                        )
                }
            }
    }
}

/// Used to workaround a SwiftUI bug. https://github.com/intitni/CopilotForXcode/issues/122
public struct CustomScrollView<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State var height: Double = 10
    @AppStorage(\.useCustomScrollViewWorkaround) var useNSScrollViewWrapper

    public init(content: @escaping () -> Content) {
        self.content = content
    }
    
    public var body: some View {
        if useNSScrollViewWrapper {
            List {
                content()
                    .listRowInsets(EdgeInsets(top: 0, leading: -8, bottom: 0, trailing: -8))
                    .modifier(CustomScrollViewUpdateHeightModifier())
            }
            .listStyle(.plain)
            .modify { view in
                if #available(macOS 13.0, *) {
                    view.listRowSeparator(.hidden).listSectionSeparator(.hidden)
                } else {
                    view
                }
            }
            .frame(idealHeight: max(10, height))
            .onPreferenceChange(CustomScrollViewHeightPreferenceKey.self) { newHeight in
                Task { @MainActor in
                    height = newHeight
                }
            }
        } else {
            ScrollView {
                content()
            }
        }
    }
}

