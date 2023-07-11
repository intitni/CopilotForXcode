import AppKit
import SwiftUI

public struct CopyButton: View {
    public var copy: () -> Void
    @State var isCopied = false
    
    public init(copy: @escaping () -> Void) {
        self.copy = copy
    }
    
    public var body: some View {
        Button(action: {
            withAnimation(.linear(duration: 0.1)) {
                isCopied = true
            }
            copy()
            Task {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                withAnimation(.linear(duration: 0.1)) {
                    isCopied = false
                }
            }
        }) {
            Image(systemName: isCopied ? "checkmark.circle" : "doc.on.doc")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .frame(width: 20, height: 20, alignment: .center)
                .foregroundColor(.secondary)
                .background(
                    .regularMaterial,
                    in: RoundedRectangle(cornerRadius: 4, style: .circular)
                )
                .padding(4)
        }
        .buttonStyle(.borderless)
    }
}
