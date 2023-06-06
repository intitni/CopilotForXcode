import ChatPlugin
import Foundation
import LangChain
import Logger
import OpenAIService

let systemPrompt = """
Translate a math problem into a expression that can be executed using Python's numexpr library.
Use the output of running this code to answer the question.

Question: ${{Question with math problem.}}
```text
${{single line mathematical expression that solves the problem}}
```
...numexpr.evaluate(text)...
```output
${{Output of running the code}}
```
Answer: ${{Answer}}

Begin.

Question: What is 37593 * 67?
```text
37593 * 67
```
...numexpr.evaluate("37593 * 67")...
```output
2518731
```
Answer: 2518731

Question: 37593^(1/5)
```text
37593**(1/5)
```
...numexpr.evaluate("37593**(1/5)")...
```output
8.222831614237718
```
Answer: 8.222831614237718
"""

/// Extract the math problem with ChatGPT, and pass it to python to get the result.
///
/// [llm_math in
/// LangChain](https://github.com/hwchase17/langchain/blob/master/langchain/chains/llm_math/base.py)
///
/// The logic is basically the same as the LLMMathChain provided in LangChain.
func solveMathProblem(_ question: String) async throws -> String {
    guard let reply = try await askChatGPT(
        systemPrompt: systemPrompt,
        question: "Question: \(question)",
        temperature: 0
    ) else { return "No answer." }

    // parse inside text code block
    let codeBlockRegex = try NSRegularExpression(pattern: "```text\n(.*?)\n```", options: [])
    let codeBlockMatches = codeBlockRegex.matches(
        in: reply,
        options: [],
        range: NSRange(reply.startIndex..<reply.endIndex, in: reply)
    )
    if let firstMatch = codeBlockMatches.first, let textRange = Range(
        firstMatch.range(at: 1),
        in: reply
    ) {
        let text = reply[textRange]
        let expression = String(text)
        let task = Task { try evaluateWithPython(expression) }
        if let answer = try await task.value {
            return answer
        }
    }

    // parse after Answer:
    let answerRegex = try NSRegularExpression(pattern: "Answer: (.*)", options: [])
    let answerMatches = answerRegex.matches(
        in: reply,
        options: [],
        range: NSRange(reply.startIndex..<reply.endIndex, in: reply)
    )
    if let firstMatch = answerMatches.first, let answerRange = Range(
        firstMatch.range(at: 1),
        in: reply
    ) {
        let answer = reply[answerRange]
        return String(answer)
    }

    return reply
}

func evaluateWithPython(_ expression: String) throws -> String? {
    let mathExpression = NSExpression(format: expression)
    let value = mathExpression.expressionValue(with: nil, context: nil)
    Logger.service.debug(String(describing: value))
    return (value as? Int).flatMap(String.init)
}

