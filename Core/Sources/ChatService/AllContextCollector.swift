import ActiveDocumentChatContextCollector
import ChatContextCollector
import WebChatContextCollector

let allContextCollectors: [any ChatContextCollector] = [
    LegacyActiveDocumentChatContextCollector(),
    WebChatContextCollector(),
]

