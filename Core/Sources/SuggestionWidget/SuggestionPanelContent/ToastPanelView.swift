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
                }

                ForEach(store.toast.messages) { message in
                    message.content
                        .foregroundColor(.white)
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
                                .stroke(Color.black.opacity(0.3), lineWidth: 1)
                        }
                }

                if store.alignTopToAnchor {
                    Spacer()
                }
            }
            .colorScheme(store.colorScheme)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
    }
}

