import SwiftUI

struct LaunchAgentView: View {
    @State var errorMessage: String?
    @State var isDidRemoveLaunchAgentAlertPresented = false
    @State var isDidSetupLaunchAgentAlertPresented = false

    var body: some View {
        Section {
            HStack {
                Button(action: {
                    do {
                        try LaunchAgentManager().setupLaunchAgent()
                        isDidSetupLaunchAgentAlertPresented = true
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }) {
                    Text("Set Up Launch Agent for XPC Service")
                }
                .alert(isPresented: $isDidSetupLaunchAgentAlertPresented) {
                    .init(
                        title: Text("Finished Launch Agent Setup"),
                        message: Text(
                            "You may need to restart Xcode to make the extension work."
                        ),
                        dismissButton: .default(Text("OK"))
                    )
                }

                Button(action: {
                    do {
                        try LaunchAgentManager().removeLaunchAgent()
                        isDidRemoveLaunchAgentAlertPresented = true
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }) {
                    Text("Remove Launch Agent")
                }
                .alert(isPresented: $isDidRemoveLaunchAgentAlertPresented) {
                    .init(
                        title: Text("Launch Agent Removed"),
                        dismissButton: .default(Text("OK"))
                    )
                }

                EmptyView()
                    .alert(isPresented: .init(
                        get: { errorMessage != nil },
                        set: { yes in
                            if !yes { errorMessage = nil }
                        }
                    )) {
                        .init(
                            title: Text("Failed. Got to the GitHub page for Help"),
                            message: Text(errorMessage ?? "Unknown Error"),
                            dismissButton: .default(Text("OK"))
                        )
                    }
            }
        }.buttonStyle(.copilot)
    }
}

struct LaunchAgentView_Preview: PreviewProvider {
    static var previews: some View {
        LaunchAgentView()
            .background(.black)
    }
}
