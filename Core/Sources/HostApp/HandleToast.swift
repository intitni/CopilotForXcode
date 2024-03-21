import Dependencies
import SwiftUI
import Toast

struct ToastHandler: View {
    @ObservedObject var toastController: ToastController
    let namespace: String?

    init(toastController: ToastController, namespace: String?) {
        _toastController = .init(wrappedValue: toastController)
        self.namespace = namespace
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(toastController.messages) { message in
                if let n = message.namespace, n != namespace {
                    EmptyView()
                } else {
                    message.content
                        .foregroundColor(.white)
                        .padding(8)
                        .background({
                            switch message.type {
                            case .info: return Color.accentColor
                            case .error: return Color(nsColor: .systemRed)
                            case .warning: return Color(nsColor: .systemOrange)
                            }
                        }() as Color, in: RoundedRectangle(cornerRadius: 8))
                        .shadow(color: Color.black.opacity(0.2), radius: 4)
                }
            }
        }
        .padding()
        .allowsHitTesting(false)
    }
}

extension View {
    func handleToast(namespace: String? = nil) -> some View {
        @Dependency(\.toastController) var toastController
        return overlay(alignment: .bottom) {
            ToastHandler(toastController: toastController, namespace: namespace)
        }.environment(\.toast) { [toastController] content, type in
            toastController.toast(content: content, type: type, namespace: namespace)
        }
    }
}

