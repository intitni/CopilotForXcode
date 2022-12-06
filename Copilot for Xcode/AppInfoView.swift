import SwiftUI

struct AppInfoView: View {
    @State var appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    
    var body: some View {
        Section {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    Text("Copilot For Xcode")
                        .font(.title)
                    Text(appVersion ?? "")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Spacer()
                }

                Link(destination: URL(string: "https://github.com/intitni/CopilotForXcode")!) {
                    HStack(spacing: 2) {
                        Image(systemName: "link")
                        Text("GitHub")
                    }
                }
                .focusable(false)
            }
        }
    }
}

struct AppInfoView_Preview: PreviewProvider {
    static var previews: some View {
        AppInfoView()
            .background(.black)
    }
}
