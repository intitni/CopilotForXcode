import ChatContextCollector
import Foundation
import OpenAIService
import Preferences
import XcodeInspector

final class DynamicContextController {
    let contextCollectors: [ChatContextCollector]
    let memory: AutoManagedChatGPTMemory
    let functionProvider: ChatFunctionProvider
    let configuration: OverridingChatGPTConfiguration
    var defaultScopes = [] as Set<ChatContext.Scope>

    convenience init(
        memory: AutoManagedChatGPTMemory,
        functionProvider: ChatFunctionProvider,
        configuration: OverridingChatGPTConfiguration,
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
        configuration: OverridingChatGPTConfiguration,
        contextCollectors: [ChatContextCollector]
    ) {
        self.memory = memory
        self.functionProvider = functionProvider
        self.configuration = configuration
        self.contextCollectors = contextCollectors
    }

    func collectContextInformation(systemPrompt: String, content: String) async throws {
        var content = content
        var scopes = Self.parseScopes(&content)
        scopes.formUnion(defaultScopes)

        let overridingChatModelId = {
            var ids = [String]()
            if scopes.contains(.sense) {
                ids.append(UserDefaults.shared.value(for: \.preferredChatModelIdForSenseScope))
            }

            if scopes.contains(.project) {
                ids.append(UserDefaults.shared.value(for: \.preferredChatModelIdForProjectScope))
            }

            if scopes.contains(.web) {
                ids.append(UserDefaults.shared.value(for: \.preferredChatModelIdForWebScope))
            }

            let chatModels = UserDefaults.shared.value(for: \.chatModels)
            let idIndexMap = chatModels.enumerated().reduce(into: [String: Int]()) {
                $0[$1.element.id] = $1.offset
            }
            return ids.filter { !$0.isEmpty }.sorted(by: {
                let lhs = idIndexMap[$0] ?? Int.max
                let rhs = idIndexMap[$1] ?? Int.max
                return lhs < rhs
            }).first
        }()

        configuration.overriding.modelId = overridingChatModelId

        functionProvider.removeAll()
        let language = UserDefaults.shared.value(for: \.chatGPTLanguage)
        let oldMessages = await memory.history
        let contexts = await withTaskGroup(
            of: ChatContext.self
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
                contexts.append(context)
            }
            return contexts
        }

        let contextSystemPrompt = contexts
            .map(\.systemPrompt)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let retrievedContent = contexts
            .flatMap(\.retrievedContent)
            .filter { !$0.document.content.isEmpty }
            .sorted { $0.priority > $1.priority }
            .prefix(15)

        let contextualSystemPrompt = """
        \(language.isEmpty ? "" : "You must always reply in \(language)")
        \(systemPrompt)
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        await memory.mutateSystemPrompt(contextualSystemPrompt)
        await memory.mutateContextSystemPrompt(contextSystemPrompt)
        await memory.mutateRetrievedContent(retrievedContent.map(\.document))
        functionProvider.append(functions: contexts.flatMap(\.functions))
    }
}

extension DynamicContextController {
    static func parseScopes(_ prompt: inout String) -> Set<ChatContext.Scope> {
        let parser = MessageScopeParser()
        return parser(&prompt)
    }
}

