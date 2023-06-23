import SwiftUI

struct ErrorPanel: View {
    var viewModel: SharedPanelViewModel
    var displayController: SharedPanelDisplayController
    var description: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(description)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.white)
                .padding()
                .background(Color.red)
            
            // close button
            Button(action: {
                displayController.isPanelDisplayed = false
                viewModel.content = nil
            }) {
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
