import ActiveDocumentChatContextCollector
import ChatContextCollector
import SystemInfoChatContextCollector
import WebChatContextCollector

let allContextCollectors: [any ChatContextCollector] = [
    SystemInfoChatContextCollector(),
    ActiveDocumentChatContextCollector(),
    WebChatContextCollector(),
]

