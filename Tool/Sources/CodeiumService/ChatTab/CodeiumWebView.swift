import ComposableArchitecture
import Foundation
import Logger
import Preferences
import WebKit

class ScriptHandler: NSObject, WKScriptMessageHandlerWithReply {
    @MainActor
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) async -> (Any?, String?) {
        if message.name == "decodeBase64", let code = message.body as? String {
            return (String(data: Data(base64Encoded: code) ?? Data(), encoding: .utf8), nil)
        }
        return (nil, nil)
    }
}

@MainActor
class CodeiumWebView: WKWebView {
    var getEditorContent: () async -> CodeiumChatTab.EditorContent
    let scriptHandler = ScriptHandler()
    weak var store: StoreOf<CodeiumChatBrowser>?

    init(getEditorContent: @escaping () async -> CodeiumChatTab.EditorContent) {
        self.getEditorContent = getEditorContent
        super.init(frame: .zero, configuration: WKWebViewConfiguration())

        if #available(macOS 13.3, *) {
            #if DEBUG
            isInspectable = true
            #endif
        }

        configuration.userContentController.addScriptMessageHandler(
            scriptHandler,
            contentWorld: .page,
            name: "decodeBase64"
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    func evaluateJavaScript(safe javaScriptString: String) async throws -> Any? {
        try await withUnsafeThrowingContinuation { continuation in
            evaluateJavaScript(javaScriptString) { result, error in
                if let error {
                    print(javaScriptString, error.localizedDescription)
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }
}

// MARK: - WebView Delegate

final class WKWebViewDelegate: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let store: StoreOf<CodeiumChatBrowser>

    init(store: StoreOf<CodeiumChatBrowser>) {
        self.store = store
    }
}

