import SwiftUI

struct CopilotButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .foregroundColor(.white)
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

struct CopilotTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .colorScheme(.dark)
            .textFieldStyle(.plain)
            .foregroundColor(.white)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white.opacity(0.2))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(.white.opacity(0.2), style: .init(lineWidth: 1))
            }
    }
}

extension TextFieldStyle where Self == CopilotTextFieldStyle {
    static var copilot: CopilotTextFieldStyle { CopilotTextFieldStyle() }
}

struct CopilotStyle_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Button") {}
                .buttonStyle(.copilot)

            TextField("title", text: .constant("Placeholder"))
                .textFieldStyle(.copilot)
        }
        .padding(.all, 8)
        .background(Color.black)
    }
}
