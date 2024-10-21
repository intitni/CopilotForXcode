import LegacyChatPlugin
import MathChatPlugin
import SearchChatPlugin
import ShortcutChatPlugin

let allPlugins: [LegacyChatPlugin.Type] = [
    TerminalChatPlugin.self,
    MathChatPlugin.self,
    SearchChatPlugin.self,
    ShortcutChatPlugin.self,
    ShortcutInputChatPlugin.self,
]

