import SwiftUI

struct CopilotButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        configuration.isPressed
                            ? Color("ButtonBackgroundColorPressed")
                            : Color("ButtonBackgroundColorDefault")
                    )
                    .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.2), style: .init(lineWidth: 1))
            }
    }
}

extension ButtonStyle where Self == CopilotButtonStyle {
    static var copilot: CopilotButtonStyle { CopilotButtonStyle() }
}
