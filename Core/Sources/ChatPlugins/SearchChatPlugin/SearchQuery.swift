import BingSearchService
import Foundation
import LangChain

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

    let chatModel = OpenAIChat(temperature: 0, stream: true)

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

    class ResultCallbackManager: ChainCallbackManager {
        var accumulation: String = ""
        var isGeneratingFinalAnswer = false
        var onFinalAnswerToken: (String) -> Void
        var onAgentActionStart: (String) -> Void
        var onAgentActionEnd: (String) -> Void

        init(
            onFinalAnswerToken: @escaping (String) -> Void,
            onAgentActionStart: @escaping (String) -> Void,
            onAgentActionEnd: @escaping (String) -> Void
        ) {
            self.onFinalAnswerToken = onFinalAnswerToken
            self.onAgentActionStart = onAgentActionStart
            self.onAgentActionEnd = onAgentActionEnd
        }

        func onChainStart<T>(type: T.Type, input: T.Input) where T: LangChain.Chain {}

        func onAgentFinish(output: LangChain.AgentFinish) {}

        func onAgentActionStart(action: LangChain.AgentAction) {
            onAgentActionStart("\(action.toolName): \(action.toolInput)")
        }

        func onAgentActionEnd(action: LangChain.AgentAction) {
            onAgentActionEnd("\(action.toolName): \(action.toolInput)")
        }

        func onLLMNewToken(token: String) {
            if isGeneratingFinalAnswer {
                onFinalAnswerToken(token)
                return
            }
            accumulation.append(token)
            if accumulation.hasSuffix("Final Answer: ") {
                isGeneratingFinalAnswer = true
                accumulation = ""
            }
        }
    }

    return (AsyncThrowingStream<SearchEvent, Error> { continuation in
        let callback = ResultCallbackManager(
            onFinalAnswerToken: {
                continuation.yield(.answerToken($0))
            },
            onAgentActionStart: {
                continuation.yield(.startAction($0))
            },
            onAgentActionEnd: {
                continuation.yield(.endAction($0))
            }
        )
        Task {
            do {
                let finalAnswer = try await agentExecutor.run(query, callbackManagers: [callback])
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

