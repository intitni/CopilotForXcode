import AppKit
import Client
import CopilotModel
import SwiftUI

struct AccountView: View {
    enum Location {
        case account
        case gitHubCopilot
        case openAI
    }

    @State var location: Location = .account

    func navigate(to: Location) {
        withAnimation(.easeInOut(duration: 0.2)) {
            location = to
        }
    }

    var body: some View {
        Section {
            switch location {
            case .account:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accounts")
                        .font(.title)
                        .padding(.bottom, 12)

                    HStack {
                        Button {
                            navigate(to: .gitHubCopilot)
                        } label: {
                            Text("GitHub Copilot")
                        }.buttonStyle(CopilotButtonStyle())

                        Button {
                            navigate(to: .openAI)
                        } label: {
                            Text("OpenAI")
                        }.buttonStyle(CopilotButtonStyle())

                        Spacer()
                    }
                }
            case .gitHubCopilot:
                ChildPage(content: {
                    CopilotView()
                }, onBackButtonClick: {
                    navigate(to: .account)
                })
            case .openAI:
                ChildPage(content: {
                    OpenAIView()
                }, onBackButtonClick: {
                    navigate(to: .account)
                })
            }
        }
    }

    struct ChildPage<V: View>: View {
        var content: () -> V
        var onBackButtonClick: () -> Void
        var body: some View {
            VStack(alignment: .leading) {
                Button(action: onBackButtonClick) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Accounts")
                    }
                    .font(.title3)
                }
                .buttonStyle(.plain)
                content()
            }
        }
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            AccountView()

            AccountView(location: .gitHubCopilot)

            AccountView(location: .openAI)
        }
        .frame(height: 800)
        .padding(.all, 8)
        .background(Color.black)
    }
}
