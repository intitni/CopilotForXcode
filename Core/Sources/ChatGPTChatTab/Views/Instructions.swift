import ComposableArchitecture
import Foundation
import MarkdownUI
import SwiftUI

struct Instruction: View {
    let chat: StoreOf<Chat>

    var body: some View {
        WithPerceptionTracking {
            Group {
                Markdown(
                """
                You can use plugins to perform various tasks.
                
                | Plugin Name | Description |
                | --- | --- |
                | `/run` | Runs a command under the project root |
                | `/math` | Solves a math problem in natural language |
                | `/search` | Searches on Bing and summarizes the results |
                | `/shortcut(name)` | Runs a shortcut from the Shortcuts.app, with the previous message as input |
                | `/shortcutInput(name)` | Runs a shortcut and uses its result as a new message |
                
                To use plugins, you can prefix a message with `/pluginName`.
                """
                )
                .modifier(InstructionModifier())
                
                Markdown(
                """
                You can use scopes to give the bot extra abilities.
                
                | Scope Name | Abilities |
                | --- | --- |
                | `@file` | Read the metadata of the editing file |
                | `@code` | Read the code and metadata in the editing file |
                | `@sense`| Experimental. Read the relevant code of the focused editor |
                | `@project` | Experimental. Access content of the project |
                | `@web` (beta) | Search on Bing or query from a web page |
                
                To use scopes, you can prefix a message with `@code`.
                
                You can use shorthand to represent a scope, such as `@c`, and enable multiple scopes with `@c+web`.
                """
                )
                .modifier(InstructionModifier())
                
                let scopes = chat.chatMenu.defaultScopes
                Markdown(
                """
                Hello, I am your AI programming assistant. I can identify issues, explain and even improve code.
                
                \({
                    if scopes.isEmpty {
                        return "No scope is enabled by default"
                    } else {
                        let scopes = scopes.map(\.rawValue).sorted()
                            .joined(separator: ", ")
                        return "Default scopes: `\(scopes)`"
                    }
                }())
                """
                )
                .modifier(InstructionModifier())
            }
        }
    }

    struct InstructionModifier: ViewModifier {
        @AppStorage(\.chatFontSize) var chatFontSize

        func body(content: Content) -> some View {
            content
                .textSelection(.enabled)
                .markdownTheme(.instruction(fontSize: chatFontSize))
                .opacity(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
        }
    }
}

