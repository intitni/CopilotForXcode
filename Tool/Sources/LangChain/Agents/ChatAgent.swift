import Foundation
import Logger
import Parsing

private func formatInstruction(toolsNames: String, preferredLanguage: String) -> String {
    """
    The way you use the tools is by specifying a json blob.
    Specifically, this json should have a `action` key (with the name of the tool to use) and a `action_input` key (with the input to the tool going here).

    The only values that should be in the "action" field are: \(toolsNames)

    The $JSON_BLOB should only contain a SINGLE action, do NOT return a list of multiple actions. Here is an example of a valid $JSON_BLOB:

    ```
    {
      "action": $TOOL_NAME,
      "action_input": $INPUT
    }
    ```

    ALWAYS use the following format:

    Question: the input question you must answer
    Thought: you should always think about what to do
    Action:
    ```
    $JSON_BLOB
    ```
    Observation: the result of the action
    ... (this Thought/Action/Observation can repeat N times)
    Thought: I now know the final answer
    Final Answer: the final answer to the original input question \(preferredLanguage)
    """
}

public class ChatAgent: Agent {
    public typealias Input = String
    public typealias Output = String
    public typealias ScratchPadContent = String
    public var observationPrefix: String { "Observation: " }
    public var llmPrefix: String { "Thought: " }
    public let chatModelChain: ChatModelChain<AgentInput<String, String>>
    let tools: [AgentTool]

    public init(chatModel: ChatModel, tools: [AgentTool], preferredLanguage: String) {
        self.tools = tools
        chatModelChain = .init(
            chatModel: chatModel,
            stops: ["Observation:"],
            promptTemplate: { agentInput in
                [
                    .init(
                        role: .system,
                        content: """
                        Respond to the human as helpfully and accurately as possible. \
                        Wrap any code block in thought in <code></code>. \
                        Format final answer to be more readable, in a ordered list if possible. \
                        You have access to the following tools:

                        \(tools.map { "\($0.name): \($0.description)" }.joined(separator: "\n"))

                        \(formatInstruction(
                            toolsNames: tools.map(\.name).joined(separator: ","),
                            preferredLanguage: preferredLanguage.isEmpty
                                ? ""
                                : "(in \(preferredLanguage)"
                        ))

                        Begin! Reminder to always use the exact characters `Final Answer` when responding.
                        """
                    ),
                    agentInput.thoughts.content.isEmpty
                        ? .init(role: .user, content: agentInput.input)
                        : .init(
                            role: .user,
                            content: """
                            \(agentInput.input)

                            \(agentInput.thoughts.content)
                            """
                        ),
                ]
            }
        )
    }
    
    func constructBaseScratchpad(intermediateSteps: [AgentAction]) -> String {
        var thoughts = ""
        for step in intermediateSteps {
            thoughts += """
            \(step.log)
            \(observationPrefix)\(step.observation ?? "")
            """
        }
        return thoughts
    }

    public func constructScratchpad(intermediateSteps: [AgentAction]) -> AgentScratchPad<String> {
        let baseScratchpad = constructBaseScratchpad(intermediateSteps: intermediateSteps)
        if baseScratchpad.isEmpty { return .init(content: "") }
        return .init(content: """
        This was your previous work (but I haven't seen any of it! I only see what you return as `Final Answer`):
        \(baseScratchpad)
        (Please continue with `Thought:` or `Final Answer:`)
        """)
    }
    
    public func constructFinalScratchpad(intermediateSteps: [AgentAction]) -> AgentScratchPad<String> {
        let baseScratchpad = constructBaseScratchpad(intermediateSteps: intermediateSteps)
        if baseScratchpad.isEmpty { return .init(content: "") }
        return .init(content: """
        This was your previous work (but I haven't seen any of it! I only see what you return as `Final Answer`):
        \(baseScratchpad)
        \(llmPrefix)I now need to return a final answer based on the previous steps:
        "(Please continue with `Final Answer:`)"
        """)
    }

    public func validateTools(tools: [AgentTool]) throws {
        // no validation
    }

    public func extraPlan(input: AgentInput<String, String>) {
        // do nothing
    }

    public func parseOutput(_ output: ChatMessage) async -> AgentNextStep<Output> {
        let text = output.content ?? ""

        func parseFinalAnswerIfPossible() -> AgentNextStep<Output>? {
            let throughAnswerParser = PrefixThrough("Final Answer:")
            var parsableContent = text[...]
            do {
                _ = try throughAnswerParser.parse(&parsableContent)
                let answer = String(parsableContent)
                let output = answer.trimmingCharacters(in: .whitespacesAndNewlines)
                return .finish(AgentFinish(returnValue: .structured(output), log: text))
            } catch {
                Logger.langchain.info("Could not parse LLM output final answer: \(error)")
                return nil
            }
        }

        func parseNextActionIfPossible() -> AgentNextStep<Output>? {
            let throughActionBlockParser = PrefixThrough("""
            Action:
            ```
            """)
            let throughActionBlockSimplifiedParser = PrefixThrough("```")
            let jsonBlobParser = PrefixUpTo("```")
            var parsableContent = text[...]
            do {
                let actionBlockPrefix = try? throughActionBlockParser.parse(&parsableContent)
                if actionBlockPrefix == nil {
                    _ = try throughActionBlockSimplifiedParser.parse(&parsableContent)
                }
                let jsonBlob = try jsonBlobParser.parse(&parsableContent)

                struct Action: Codable {
                    let action: String
                    let action_input: String
                }
                let response = try JSONDecoder()
                    .decode(Action.self, from: jsonBlob.data(using: .utf8) ?? Data())
                return .actions([
                    AgentAction(
                        toolName: response.action,
                        toolInput: response.action_input,
                        log: text
                    ),
                ])
            } catch {
                Logger.langchain.info("Could not parse LLM output next action: \(error)")
                return nil
            }
        }

        if let step = parseFinalAnswerIfPossible() { return step }
        if let step = parseNextActionIfPossible() { return step }

        let forceParser = PrefixUpTo("Action:")
        var parsableContent = text[...]
        let finalAnswer = try? forceParser.parse(&parsableContent)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var answer = finalAnswer ?? text
        if answer.isEmpty {
            answer = "Sorry, I don't know."
        }

        return .finish(AgentFinish(returnValue: .structured(String(answer)), log: text))
    }
}

