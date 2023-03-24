import SwiftUI

struct ErrorPanel: View {
    var viewModel: SuggestionPanelViewModel
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
                viewModel.isPanelDisplayed = false
                viewModel.content = .empty
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
