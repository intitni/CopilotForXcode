import SuggestionModel
import Foundation

@objc(XPCServiceProtocol)
public protocol XPCServiceProtocol {
    func checkStatus(withReply reply: @escaping (String?, Error?) -> Void)
    func signInInitiate(withReply reply: @escaping (String?, String?, Error?) -> Void)
    func signInConfirm(
        userCode: String,
        withReply reply: @escaping (String?, String?, Error?) -> Void
    )
    func signOut(withReply reply: @escaping (String?, Error?) -> Void)
    func getVersion(withReply reply: @escaping (String?, Error?) -> Void)

    func getSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void
    )
    func getNextSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void
    )
    func getPreviousSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void
    )
    func getSuggestionAcceptedCode(
        editorContent: Data,
        withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void
    )
    func getSuggestionRejectedCode(
        editorContent: Data,
        withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void
    )
    func getRealtimeSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    )
    func chatWithSelection(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    )
    func promptToCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    )
    func customCommand(
        id: String,
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    )

    func toggleRealtimeSuggestion(withReply reply: @escaping (Error?) -> Void)

    func prefetchRealtimeSuggestions(
        editorContent: Data,
        withReply reply: @escaping () -> Void
    )

    func getXPCServiceVersion(withReply reply: @escaping (String, String) -> Void)
}
