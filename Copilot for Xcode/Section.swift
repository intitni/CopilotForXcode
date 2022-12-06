import SwiftUI

struct Section<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        Group {
            content()
        }
        .foregroundColor(.white)
        .padding(.all, 12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    Color.white.opacity(0.3),
                    style: .init(lineWidth: 1)
                )
                .background(.clear)
        )
    }
}

struct Section_Preview: PreviewProvider {
    static var previews: some View {
        Group {
            Section {
                VStack {
                    Text("Hello")
                    Text("World")
                }
            }
        }
        .padding(.all, 30)
        .background(Color("BackgroundColor"))
    }
}
