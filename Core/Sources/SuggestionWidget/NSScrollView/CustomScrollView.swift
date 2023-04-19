import AppKit
import SwiftUI
import Combine

/// Used to workaround a SwiftUI bug. https://github.com/intitni/CopilotForXcode/issues/122
struct CustomScrollView<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State var height: Double = 100
    @AppStorage(\.useCustomScrollViewWorkaround) var useNSScrollViewWrapper

    var body: some View {
        if useNSScrollViewWrapper {
            List {
                content()
                    .listRowInsets(EdgeInsets(top: 0, leading: -8, bottom: 0, trailing: -8))
            }
            .listStyle(.plain)
            .frame(idealHeight: height)
            .background {
                ComputeHeight(height: $height) {
                    content()
                }
                .frame(maxWidth: .infinity)
                .opacity(0)
            }
        } else {
            ScrollView {
                content()
            }
        }
    }
}

private struct ComputeHeight<Content: View>: NSViewRepresentable {
    @Binding var height: Double
    @ViewBuilder var content: () -> Content

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        updateHeight(nsView)
    }
    
    func updateHeight(_ nsView: NSView) {
        let contentView = content()
        let hostingView = NSHostingView(
            rootView: contentView.frame(width: nsView.frame.width == 0 ? 200 : nsView.frame.width)
        )
        let size = hostingView.fittingSize
        print(size)

        if height != size.height {
            Task { @MainActor in
                height = size.height
            }
        }
    }
}
