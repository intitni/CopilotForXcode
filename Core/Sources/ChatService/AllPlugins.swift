import ChatPlugin
import MathChatPlugin
import SearchChatPlugin

let allPlugins: [ChatPlugin.Type] = [
    TerminalChatPlugin.self,
    AITerminalChatPlugin.self,
    MathChatPlugin.self,
    SearchChatPlugin.self,
]
