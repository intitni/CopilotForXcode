import SwiftUI

struct InstructionView: View {
    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
// swiftformat: disable indent
Text("Instruction")
    .font(.title)
    .padding(.bottom, 12)
Text("Enable Extension")
    .font(.title3)
Text("""
1. Install Node.
2. Click `Set Up Launch Agent` to set up an XPC service to run in the background.
3. Refresh Copilot status or restart the app.
4. Click `Sign In` to sign into your GitHub account. 
5. After submitting your user code to the verification website, click `Confirm Sign-in` to finish the sign-in.
6. Go to `Settings.app > Privacy & Security > Extension > Xcode Source Editor Extension` to turn **Copilot for Xcode** on.
7. Restart Xcode, the Copilot commands should be available in the menu bar.
""")

Text("Disable Extension")
    .font(.title3)

Text("""
1. Optionally sign out of GitHub Copilot.
2. Click `Remove Launch Agent`.
""")
// swiftformat: enable indent
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

struct InstructionView_Preview: PreviewProvider {
    static var previews: some View {
        InstructionView()
            .background(.black)
            .frame(height: 600)
    }
}
