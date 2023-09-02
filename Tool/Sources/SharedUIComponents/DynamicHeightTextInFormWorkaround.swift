import SwiftUI

struct DynamicHeightTextInFormWorkaroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            content
            Spacer()
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

public extension View {
    func dynamicHeightTextInFormWorkaround() -> some View {
        modifier(DynamicHeightTextInFormWorkaroundModifier())
    }
}
