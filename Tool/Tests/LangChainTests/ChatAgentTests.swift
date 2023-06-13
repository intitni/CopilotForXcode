import XCTest
@testable import LangChain

private struct FakeChatModel: ChatModel {
    func generate(
        prompt: [LangChain.ChatMessage],
        stops: [String],
        callbackManagers: [LangChain.ChainCallbackManager]
    ) async throws -> String {
        return "New Message"
    }
}

final class ChatAgentParseOutputTests: XCTestCase {
    func test_parsing_well_formatted_final_answer() throws {
        let finalAnswer = """
        Final Answer: The answer is 42.
        Because 42 is the answer to everything.
        """

        let agent = ChatAgent(chatModel: FakeChatModel(), tools: [], preferredLanguage: "")
        let result = agent.parseOutput(finalAnswer)
        XCTAssertEqual(result, .finish(.init(
            returnValue: """
            The answer is 42.
            Because 42 is the answer to everything.
            """,
            log: finalAnswer
        )))
    }
    
    func test_parsing_final_answer_with_random_prefix() throws {
        let finalAnswer = """
        Now I have the final answer.
        Final Answer: The answer is 42.
        Because 42 is the answer to everything.
        """

        let agent = ChatAgent(chatModel: FakeChatModel(), tools: [], preferredLanguage: "")
        let result = agent.parseOutput(finalAnswer)
        XCTAssertEqual(result, .finish(.init(
            returnValue: """
            The answer is 42.
            Because 42 is the answer to everything.
            """,
            log: finalAnswer
        )))
    }
    
    func test_parsing_action() throws {
        let reply = """
        Question: How to setup langchain python?
        Thought: I am not familiar with langchain python, I should use the Search tool to find more information on how to set it up.
        Action:
        ```
        {
          "action": "Search",
          "action_input": "how to setup langchain python"
        }
        ```
        """
        
        let agent = ChatAgent(chatModel: FakeChatModel(), tools: [], preferredLanguage: "")
        let result = agent.parseOutput(reply)
        XCTAssertEqual(result, .actions([
            .init(
                toolName: "Search",
                toolInput: "how to setup langchain python",
                log: reply
            )
        ]))
    }
    
    func test_parsing_broken_action_and_return_everything_ahead_of_it() {
        let reply = """
        Question: How to setup langchain python?
        Thought: I am not familiar with langchain python, I should use the Search tool to find more information on how to set it up.
        Action:
        ```
        lkjaskdjalksjdlkasjdklj
        ```
        """
        
        let agent = ChatAgent(chatModel: FakeChatModel(), tools: [], preferredLanguage: "")
        let result = agent.parseOutput(reply)
        XCTAssertEqual(result, .finish(.init(
            returnValue: """
            Question: How to setup langchain python?
            Thought: I am not familiar with langchain python, I should use the Search tool to find more information on how to set it up.
            """,
            log: reply
        )))
    }
    
    func test_parsing_simple_reply_that_does_not_follow_the_format() {
        let reply = """
        The answer is 42.
        Because 42 is the answer to everything.
        """
        
        let agent = ChatAgent(chatModel: FakeChatModel(), tools: [], preferredLanguage: "")
        let result = agent.parseOutput(reply)
        XCTAssertEqual(result, .finish(.init(
            returnValue: reply,
            log: reply
        )))
    }
}

