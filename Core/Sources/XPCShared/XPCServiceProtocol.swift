import SuggestionModel
import Foundation

@objc(XPCServiceProtocol)
public protocol XPCServiceProtocol {
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
    func getXPCServiceAccessibilityPermission(withReply reply: @escaping (Bool) -> Void)
    func postNotification(name: String, withReply reply: @escaping () -> Void)
    func performAction(name: String, arguments: String, withReply reply: @escaping (String) -> Void)
}
