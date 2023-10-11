import SwiftUI

public extension View {
    @ViewBuilder func modify<Content: View>(@ViewBuilder transform: (Self) -> Content)
        -> some View
    {
        transform(self)
    }
}

