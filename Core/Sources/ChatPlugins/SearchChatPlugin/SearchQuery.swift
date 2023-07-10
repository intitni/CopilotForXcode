import BingSearchService
import Foundation
import LangChain
import OpenAIService

enum SearchEvent {
    case startAction(String)
    case endAction(String)
    case answerToken(String)
    case finishAnswer(String, [(title: String, link: String)])
}

func search(_ query: String) async throws
    -> (stream: AsyncThrowingStream<SearchEvent, Error>, cancel: () async -> Void)
{
    let bingSearch = BingSearchService(
        subscriptionKey: UserDefaults.shared.value(for: \.bingSearchSubscriptionKey),
        searchURL: UserDefaults.shared.value(for: \.bingSearchEndpoint)
    )

    final class LinkStorage {
        var links = [(title: String, link: String)]()
    }

    let linkStorage = LinkStorage()

    let tools = [
        SimpleAgentTool(
            name: "Search",
            description: "useful for when you need to answer questions about current events. Don't search for the same thing twice",
            run: {
                linkStorage.links = []
                let result = try await bingSearch.search(query: $0, numberOfResult: 5)
                let websites = result.webPages.value

                var string = ""
                for (index, website) in websites.enumerated() {
                    string.append("[\(index)]:###\(website.snippet)###\n")
                    linkStorage.links.append((website.name, website.url))
                }
                return string
            }
        ),
    ]

    let chatModel = OpenAIChat(
        configuration: UserPreferenceChatGPTConfiguration().overriding { $0.temperature = 0 },
        stream: true
    )

    let agentExecutor = AgentExecutor(
        agent: ChatAgent(
            chatModel: chatModel,
            tools: tools,
            preferredLanguage: UserDefaults.shared.value(for: \.chatGPTLanguage)
        ),
        tools: tools,
        maxIteration: UserDefaults.shared.value(for: \.chatSearchPluginMaxIterations),
        earlyStopHandleType: .generate
    )

    return (AsyncThrowingStream<SearchEvent, Error> { continuation in
        var accumulation: String = ""
        var isGeneratingFinalAnswer = false

        let callbackManager = CallbackManager { manager in
            manager.on(CallbackEvents.AgentActionDidStart.self) {
                continuation.yield(.startAction("\($0.toolName): \($0.toolInput)"))
            }

            manager.on(CallbackEvents.AgentActionDidEnd.self) {
                continuation.yield(.endAction("\($0.toolName): \($0.toolInput)"))
            }

            manager.on(CallbackEvents.LLMDidProduceNewToken.self) {
                if isGeneratingFinalAnswer {
                    continuation.yield(.answerToken($0))
                    return
                }
                accumulation.append($0)
                if accumulation.hasSuffix("Final Answer: ") {
                    isGeneratingFinalAnswer = true
                    accumulation = ""
                }
            }
        }
        Task {
            do {
                let finalAnswer = try await agentExecutor.run(
                    query,
                    callbackManagers: [callbackManager]
                )
                continuation.yield(.finishAnswer(finalAnswer, linkStorage.links))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }, {
        await agentExecutor.cancel()
    })
}

