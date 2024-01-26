import ComposableArchitecture
import Dependencies
import Foundation
import SwiftUI
import Toast

struct ToastPanelView: View {
    let store: StoreOf<ToastPanel>

    struct ViewState: Equatable {
        let colorScheme: ColorScheme
        let alignTopToAnchor: Bool
    }

    var body: some View {
        WithViewStore(store, observe: {
            ViewState(
                colorScheme: $0.colorScheme,
                alignTopToAnchor: $0.alignTopToAnchor
            )
        }) { viewStore in
            VStack(spacing: 4) {
                if !viewStore.alignTopToAnchor {
                    Spacer()
                }
                
                WithViewStore(store, observe: \.toast.messages) { viewStore in
                    ForEach(viewStore.state) { message in
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
                }
                
                if viewStore.alignTopToAnchor {
                    Spacer()
                }
            }
            .colorScheme(viewStore.colorScheme)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

