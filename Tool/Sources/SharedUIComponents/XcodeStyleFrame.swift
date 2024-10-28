import Foundation
import SwiftUI

public struct XcodeLikeFrame<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    let content: Content
    let cornerRadius: Double

    public init(cornerRadius: Double, content: Content) {
        self.content = content
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Material.bar)
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(0, cornerRadius), style: .continuous)
                    .stroke(Color.black.opacity(0.1), style: .init(lineWidth: 1))
            ) // Add an extra border just incase the background is not displayed.
            .overlay(
                RoundedRectangle(cornerRadius: max(0, cornerRadius - 1), style: .continuous)
                    .stroke(Color.white.opacity(0.2), style: .init(lineWidth: 1))
                    .padding(1)
            )
    }
}

public extension View {
    func xcodeStyleFrame(cornerRadius: Double? = nil) -> some View {
        XcodeLikeFrame(cornerRadius: cornerRadius ?? 10, content: self)
    }
}

