import ChatContextCollector
import Foundation
import OpenAIService
import Parsing
import Preferences
import XcodeInspector

final class DynamicContextController {
    let contextCollectors: [ChatContextCollector]
    let memory: AutoManagedChatGPTMemory
    let functionProvider: ChatFunctionProvider
    let configuration: ChatGPTConfiguration
    var defaultScopes = [] as Set<String>

    convenience init(
        memory: AutoManagedChatGPTMemory,
        functionProvider: ChatFunctionProvider,
        configuration: ChatGPTConfiguration,
        contextCollectors: ChatContextCollector...
    ) {
        self.init(
            memory: memory,
            functionProvider: functionProvider,
            configuration: configuration,
            contextCollectors: contextCollectors
        )
    }

    init(
        memory: AutoManagedChatGPTMemory,
        functionProvider: ChatFunctionProvider,
        configuration: ChatGPTConfiguration,
        contextCollectors: [ChatContextCollector]
    ) {
        self.memory = memory
        self.functionProvider = functionProvider
        self.configuration = configuration
        self.contextCollectors = contextCollectors
    }

    func updatePromptToMatchContent(systemPrompt: String, content: String) async throws {
        var content = content
        var scopes = Self.parseScopes(&content)
        scopes.formUnion(defaultScopes)

        functionProvider.removeAll()
        let language = UserDefaults.shared.value(for: \.chatGPTLanguage)
        let oldMessages = await memory.history
        let contexts = await withTaskGroup(
            of: ChatContext?.self
        ) { [scopes, content, configuration] group in
            for collector in contextCollectors {
                group.addTask {
                    await collector.generateContext(
                        history: oldMessages,
                        scopes: scopes,
                        content: content,
                        configuration: configuration
                    )
                }
            }
            var contexts = [ChatContext]()
            for await context in group {
                if let context = context {
                    contexts.append(context)
                }
            }
            return contexts
        }
        let contextualSystemPrompt = """
        \(language.isEmpty ? "" : "You must always reply in \(language)")
        \(systemPrompt)

        \(contexts.map(\.systemPrompt).filter { !$0.isEmpty }.joined(separator: "\n\n"))
        """
        await memory.mutateSystemPrompt(contextualSystemPrompt)
        functionProvider.append(functions: contexts.flatMap(\.functions))
    }
}

extension DynamicContextController {
    static func parseScopes(_ prompt: inout String) -> Set<String> {
        guard !prompt.isEmpty else { return [] }
        do {
            let parser = Parse {
                "@"
                Many {
                    Prefix { $0.isLetter }
                } separator: {
                    "+"
                } terminator: {
                    " "
                }
                Skip {
                    Many {
                        " "
                    }
                }
                Rest()
            }
            let (scopes, rest) = try parser.parse(prompt)
            prompt = String(rest)
            return Set(scopes.map(String.init))
        } catch {
            return []
        }
    }
}

