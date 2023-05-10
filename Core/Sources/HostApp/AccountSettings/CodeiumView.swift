import CodeiumService
import Foundation
import SwiftUI

struct CodeiumView: View {
    class ViewModel: ObservableObject {
        let codeiumAuthService = CodeiumAuthService()
        @Published var isSignedIn: Bool
        
        init() {
            isSignedIn = codeiumAuthService.isSignedIn
        }
        
        func generateAuthURL() -> URL {
            return URL(
                string: "https://www.codeium.com/profile?response_type=token&redirect_uri=show-auth-token&state=\(UUID().uuidString)&scope=openid%20profile%20email&redirect_parameters_type=query"
            )!
        }
        
        func signIn(token: String) async throws {
            try await codeiumAuthService.signIn(token: token)
            Task { @MainActor in isSignedIn = true }
            
        }
        
        func signOut() async throws {
            try await codeiumAuthService.signOut()
            Task { @MainActor in isSignedIn = false }
        }
    }
    
    @StateObject var viewModel = ViewModel()
    @State var isSignInPanelPresented = false

    var body: some View {
        Form {
            if viewModel.isSignedIn {
                Button(action: {
                    viewModel.isSignedIn = false
                }) {
                    Text("Sign Out")
                }
            } else {
                Button(action: {
                    isSignInPanelPresented = true
                }) {
                    Text("Sign In")
                }
            }
        }
        .sheet(isPresented: $isSignInPanelPresented) {
            CodeiumSignInView(viewModel: viewModel, isPresented: $isSignInPanelPresented)
        }
    }
}

struct CodeiumSignInView: View {
    let viewModel: CodeiumView.ViewModel
    @Binding var isPresented: Bool
    @Environment(\.openURL) var openURL
    @Environment(\.toast) var toast
    @State var isGeneratingKey = false
    @State var token = ""

    var body: some View {
        VStack {
            Text(
                "You will be redirected to codeium.com. Please paste the generated token below and click the \"Sign In\" button."
            )

            TextEditor(text: $token)
                .font(Font.system(.body, design: .monospaced))
                .padding(4)
                .frame(minHeight: 120)
                .multilineTextAlignment(.leading)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )

            Button(action: {
                isGeneratingKey = true
                Task {
                    do {
                        try await viewModel.signIn(token: token)
                        isGeneratingKey = false
                        isPresented  = false
                    } catch {
                        isGeneratingKey = false
                        toast(Text(error.localizedDescription), .error)
                    }
                }
            }) {
                Text(isGeneratingKey ? "Signing In.." : "Sign In")
            }.disabled(isGeneratingKey)
        }
        .padding()
        .onAppear {
            openURL(viewModel.generateAuthURL())
        }
    }
}

struct CodeiumView_Previews: PreviewProvider {
    static var previews: some View {
        CodeiumView()
            .frame(width: 600, height: 500)
    }
}

