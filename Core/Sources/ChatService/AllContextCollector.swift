import ActiveDocumentChatContextCollector
import ChatContextCollector
import SystemInfoChatContextCollector
import WebChatContextCollector
import ProChatContextCollectors

let allContextCollectors: [any ChatContextCollector] = [
    SystemInfoChatContextCollector(),
    ActiveDocumentChatContextCollector(),
    WebChatContextCollector(),
    ProChatContextCollectors(),
]

