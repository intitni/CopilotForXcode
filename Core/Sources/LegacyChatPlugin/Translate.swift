import Foundation
import Preferences

@MainActor
var translationCache = [String: String]()

public func translate(text: String, cache: Bool = true) async -> String {
    let language = UserDefaults.shared.value(for: \.chatGPTLanguage)
    if language.isEmpty { return text }

    let key = "\(language)-\(text)"
    if cache, let cached = await translationCache[key] {
        return cached
    }

    if let translated = try? await askChatGPT(
        systemPrompt: """
        You are a translator. Your job is to translate the message into \(language). The reply should only contain the translated content.
        User: ###${{some text}}###
        Assistant: ${{translated text}}
        """,
        question: "###\(text)###"
    ) {
        if cache {
            let storeTask = Task { @MainActor in
                translationCache[key] = translated
            }
            _ = await storeTask.result
        }
        return translated
    }
    return text
}

