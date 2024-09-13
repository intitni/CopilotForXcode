import ComposableArchitecture
import Dependencies
import Foundation
import SwiftUI
import Toast

struct ToastPanelView: View {
    let store: StoreOf<ToastPanel>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 4) {
                if !store.alignTopToAnchor {
                    Spacer()
                        .allowsHitTesting(false)
                }

                ForEach(store.toast.messages) { message in
                    HStack {
                        message.content
                            .foregroundColor(.white)
                            .textSelection(.enabled)
                        

                        if !message.buttons.isEmpty {
                            HStack {
                                ForEach(
                                    Array(message.buttons.enumerated()),
                                    id: \.offset
                                ) { _, button in
                                    Button(action: button.action) {
                                        button.label
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(Color.white, lineWidth: 1)
                                            }
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .allowsHitTesting(true)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background({
                        switch message.type {
                        case .info: return Color.accentColor
                        case .error: return Color(nsColor: .systemRed)
                        case .warning: return Color(nsColor: .systemOrange)
                        }
                    }() as Color, in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    }
                }

                if store.alignTopToAnchor {
                    Spacer()
                        .allowsHitTesting(false)
                }
            }
            .colorScheme(store.colorScheme)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ToastPanelView(store: .init(initialState: .init(
        toast: .init(messages: [
            ToastController.Message(
                id: UUID(),
                type: .info,
                content: Text("Info message"),
                buttons: [
                    .init(label: Text("Dismiss"), action: {}),
                    .init(label: Text("More info"), action: {}),
                ]
            ),
            ToastController.Message(
                id: UUID(),
                type: .error,
                content: Text("Error message"),
                buttons: [.init(label: Text("Dismiss"), action: {})]
            ),
            ToastController.Message(
                id: UUID(),
                type: .warning,
                content: Text("Warning message"),
                buttons: [.init(label: Text("Dismiss"), action: {})]
            ),
        ])
    ), reducer: {
        ToastPanel()
    }))
}

