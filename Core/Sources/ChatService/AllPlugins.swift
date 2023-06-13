import ChatPlugin
import MathChatPlugin
import SearchChatPlugin
import ShortcutChatPlugin

let allPlugins: [ChatPlugin.Type] = [
    TerminalChatPlugin.self,
    AITerminalChatPlugin.self,
    MathChatPlugin.self,
    SearchChatPlugin.self,
    ShortcutChatPlugin.self,
    ShortcutInputChatPlugin.self,
]

