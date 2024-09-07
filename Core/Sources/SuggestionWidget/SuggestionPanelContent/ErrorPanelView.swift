import SwiftUI

struct ErrorPanelView: View {
    var description: String
    var onCloseButtonTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(description)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
            
            // close button
            Button(action: onCloseButtonTap) {
                Image(systemName: "xmark")
                    .padding([.leading, .bottom], 16)
                    .padding([.top, .trailing], 8)
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .xcodeStyleFrame()
    }
}
