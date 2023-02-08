import SwiftUI

struct InstructionView: View {
    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    // swiftformat:disable indent
Text("Instruction")
    .font(.title)
    .padding(.bottom, 12)
Text("Enable Extension")
    .font(.title3)
Text("""
1. Install Node.
2. Click `Set Up Launch Agent` to set up an XPC service to run in the background.
3. Refresh Copilot status (it may fail the first time).
4. Click `Sign In` to sign into your GitHub account.
5. After submitting your user code to the verification site, click `Confirm Sign-in` to complete the sign-in.
6. Go to `System Settings.app > Privacy & Security > Extensions > Xcode Source Editor` , check the **Copilot** checkbox to enable the extension.
7. Restart Xcode, the Copilot commands should be available in the menu bar.
""")
                    
Text("Granting Permissions")
    .font(.title3)
Text("""
The app needs at least **Accessibility API** permissions to work. If you are using real-time suggestions and it doesn't work properly with **Accessibility API** permissions, try also enabling **Input Monitoring**..

please visit the [project's GitHub page](https://github.com/intitni/CopilotForXcode#granting-permissions-to-the-app) for instructions.
""")

Text("Disable Extension")
    .font(.title3)

Text("""
1. Optionally sign out of GitHub Copilot.
2. Click `Remove Launch Agent`.
""")

Text(
    "For detailed instructions, please visit the [project's GitHub page](https://github.com/intitni/CopilotForXcode)."
)
                    // swiftformat:enable indent
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
