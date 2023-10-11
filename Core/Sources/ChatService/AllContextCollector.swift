import ActiveDocumentChatContextCollector
import ChatContextCollector
import SystemInfoChatContextCollector
import WebChatContextCollector
#if canImport(ProChatContextCollectors)
import ProChatContextCollectors
let allContextCollectors: [any ChatContextCollector] = [
    SystemInfoChatContextCollector(),
    WebChatContextCollector(),
    ProChatContextCollectors(),
]
#else
let allContextCollectors: [any ChatContextCollector] = [
    SystemInfoChatContextCollector(),
    ActiveDocumentChatContextCollector(),
    WebChatContextCollector(),
]
#endif

