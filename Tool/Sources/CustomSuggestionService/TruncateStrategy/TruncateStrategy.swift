import CopilotForXcodeKit
import Foundation

public protocol TruncateStrategy {
    func createTruncatedPrompt(promptStrategy: PromptStrategy) -> [PromptMessage]
}

public struct DefaultTruncateStrategy: TruncateStrategy {
    let maxTokenLimit: Int
    let countToken: ([PromptMessage]) -> Int

    public init(maxTokenLimit: Int, countToken: @escaping ([PromptMessage]) -> Int = {
        $0.reduce(0) { $0 + $1.content.count }
    }) {
        self.maxTokenLimit = maxTokenLimit
        self.countToken = countToken
    }

    public func createTruncatedPrompt(promptStrategy: PromptStrategy) -> [PromptMessage] {
        var prefix = promptStrategy.prefix
        var suffix = promptStrategy.suffix
        var snippets = promptStrategy.relevantCodeSnippets

        var prompts = promptStrategy.createPrompt(
            truncatedPrefix: prefix,
            truncatedSuffix: suffix,
            includedSnippets: snippets
        )

        let limit = maxTokenLimit - countToken([.init(
            role: .user,
            content: promptStrategy.systemPrompt
        )])

        let prefixDropWeight = 1
        let suffixDropWeight = 5
        let snippetsDropWeight = 8

        while countToken(prompts) > limit,
              !(prefix.isEmpty && suffix.isEmpty && snippets.isEmpty)
        {
            let p = prefix.count * prefixDropWeight
            let s = suffix.count * suffixDropWeight
            let n = snippets.count * snippetsDropWeight

            let maxScore = max(p, s, n)
            switch maxScore {
            case s:
                truncateSuffix(&suffix)
            case n:
                truncateSnippets(&snippets)
            case p:
                truncatePrefix(&prefix)
            default:
                truncateSuffix(&suffix)
            }

            prompts = promptStrategy.createPrompt(
                truncatedPrefix: prefix,
                truncatedSuffix: suffix,
                includedSnippets: snippets
            )
        }

        return prompts
    }

    /// Drop the last one third.
    func truncateSuffix(_ suffix: inout [String]) {
        let step = 3

        if suffix.isEmpty { return }
        let dropCount = max(suffix.count / step, 1)
        suffix.removeLast(dropCount)
    }

    /// Drop the leading one fourth.
    func truncatePrefix(_ prefix: inout [String]) {
        let step = 4

        if prefix.isEmpty { return }
        let dropCount = max(prefix.count / step, 1)
        prefix.removeFirst(dropCount)
    }

    func truncateSnippets(_ snippets: inout [RelevantCodeSnippet]) {
        if snippets.isEmpty { return }
        snippets.removeLast()
    }
}

