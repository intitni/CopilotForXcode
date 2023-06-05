import Foundation
import LangChain
import PythonHelper
import PythonKit

func search(_ query: String) async throws -> String {
    #if DEBUG
    let verbose = true
    #else
    let verbose = false
    #endif

    let task = Task {
        try runPython {
            let llm = try LangChainChatModel.DynamicChatOpenAI(temperature: 0)
            let utilities = try Python.attemptImportOnPythonThread("langchain.utilities")
            let BingSearchAPIWrapper = utilities.BingSearchAPIWrapper
            let agents = try Python.attemptImportOnPythonThread("langchain.agents")
            let Tool = agents.Tool
            let initializeAgent = agents.initialize_agent
            let AgentType = agents.AgentType

            let bingSearch = BingSearchAPIWrapper(
                bing_subscription_key: "f1eaef707e9443ddb08df2cfb6ac1eb5",
                bing_search_url: "https://api.bing.microsoft.com/v7.0/search/",
                k: 5
            )

            var links = [String]()

            let getSearchResult = PythonInstanceMethod { arguments -> String in
                guard let query = arguments.first else { return "Empty" }
                let results = bingSearch.results(query, 5)
                let resultString = results.enumerated().map { "[\($0)]:###\($1["snippet"])###" }
                    .joined(separator: "\n")
                links = results.map {
                    let url = String($0["link"]) ?? "N/A"
                    let title = String($0["title"]) ?? "Unknown Title"
                    return "[\(title)](\(url))"
                }
                return resultString
            }
            
            let ff = PythonClass("FF", members: [
                "run": PythonInstanceMethod { arguments -> String in
                    guard let query = arguments.first else { return "Empty" }
                    let results = bingSearch.results(query, 5)
                    let resultString = results.enumerated().map { "[\($0)]:###\($1["snippet"])###" }
                        .joined(separator: "\n")
                    links = results.map {
                        let url = String($0["link"]) ?? "N/A"
                        let title = String($0["title"]) ?? "Unknown Title"
                        return "[\(title)](\(url))"
                    }
                    return resultString
                }
            ])
            
            let fi = ff.pythonObject()
            
            print(fi.run)
            print(getSearchResult.pythonObject)

            let tools = [
                Tool(
                    name: "Search",
                    func: fi.run,
                    description: "useful for when you need to answer questions about current events. You should ask targeted questions"
                ),
            ]

            let chain = initializeAgent(
                tools, llm,
                agent: AgentType.CHAT_ZERO_SHOT_REACT_DESCRIPTION,
                verbose: verbose,
                max_iterations: 1,
                early_stopping_method: "generate",
                agent_kwargs: ["system_message_prefix": "Respond to the human as helpfully and accurately as possible. Wrap any code block in thought in <code></code>. Format final answer to be more readable, in a ordered list if possible. You have access to the following tools:"]
            )

            let trimmedQuery = query.trimmingCharacters(in: [" ", "\n"])
            do {
                let result = try chain.run.throwing.dynamicallyCall(withArguments: trimmedQuery)
                return (String(result) ?? "", links)
            } catch {
                return (error.localizedDescription, links)
            }
        }
    }

    let (answer, links) = try await task.value

    return """
    \(answer)
    ------
    \(links.map { "- \($0)" }.joined(separator: "\n"))
    """
}

