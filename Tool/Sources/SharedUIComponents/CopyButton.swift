import AppKit
import SwiftUI

public struct CopyButton: View {
    public var copy: () -> Void
    @State var isCopied = false

    public init(copy: @escaping () -> Void) {
        self.copy = copy
    }

    public var body: some View {
        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 14, height: 14)
            .frame(width: 20, height: 20, alignment: .center)
            .foregroundColor(.secondary)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 4, style: .circular)
            )
            .background {
                RoundedRectangle(cornerRadius: 4, style: .circular)
                    .fill(Color.primary.opacity(0.1))
            }
            .padding(4)
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
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
                    }
            )
    }
}

public struct DraggableCopyButton: View {
    public var content: () -> String

    public init(content: @escaping () -> String) {
        self.content = content
    }

    public var body: some View {
        CopyButton {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content(), forType: .string)
        }
        .onDrag {
            NSItemProvider(object: content() as NSString)
        }
    }
}

