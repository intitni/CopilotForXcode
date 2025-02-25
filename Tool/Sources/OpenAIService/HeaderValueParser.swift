import Foundation
import GitHubCopilotService
import Logger
import Terminal

public struct HeaderValueParser {
    public enum Placeholder: String {
        case gitHubCopilotOBearerToken = "github_copilot_bearer_token"
        case apiKey = "api_key"
        case modelName = "model_name"
    }

    public struct Context {
        public var modelName: String
        public var apiKey: String
        public var gitHubCopilotToken: () async -> GitHubCopilotExtension.Token?
        public var shellEnvironmentVariable: (_ key: String) async -> String?

        public init(
            modelName: String,
            apiKey: String,
            gitHubCopilotToken: (() async -> GitHubCopilotExtension.Token?)? = nil,
            shellEnvironmentVariable: ((_: String) async -> String?)? = nil
        ) {
            self.modelName = modelName
            self.apiKey = apiKey
            self.gitHubCopilotToken = gitHubCopilotToken ?? {
                try? await GitHubCopilotExtension.fetchToken()
            }
            self.shellEnvironmentVariable = shellEnvironmentVariable ?? { p in
                let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/bash"
                let terminal = Terminal()
                return try? await terminal.runCommand(
                    shell,
                    arguments: ["-i", "-l", "-c", "echo $\(p)"],
                    environment: [:]
                )
            }
        }
    }

    public init() {}

    /// Replace `{{PlaceHolder}}` with exact values.
    public func parse(_ value: String, context: Context) async -> String {
        var parsedValue = value
        let placeholderRanges = findPlaceholderRanges(in: parsedValue)

        for (range, placeholderText) in placeholderRanges.reversed() {
            let cleanPlaceholder = placeholderText
                .trimmingCharacters(in: CharacterSet(charactersIn: "{}"))

            var replacement: String?
            if let knownPlaceholder = Placeholder(rawValue: cleanPlaceholder) {
                async let token = context.gitHubCopilotToken()
                switch knownPlaceholder {
                case .gitHubCopilotOBearerToken:
                    replacement = await token?.token
                case .apiKey:
                    replacement = context.apiKey
                case .modelName:
                    replacement = context.modelName
                }
            } else {
                replacement = await context.shellEnvironmentVariable(cleanPlaceholder)
            }

            if let replacement {
                parsedValue.replaceSubrange(
                    range,
                    with: replacement.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } else {
                parsedValue.replaceSubrange(range, with: "none")
            }
        }

        return parsedValue
    }

    private func findPlaceholderRanges(in string: String) -> [(Range<String.Index>, String)] {
        var ranges: [(Range<String.Index>, String)] = []
        let pattern = #"\{\{[^}]+\}\}"#

        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let matches = regex.matches(
                in: string,
                range: NSRange(string.startIndex..., in: string)
            )

            for match in matches {
                if let range = Range(match.range, in: string) {
                    ranges.append((range, String(string[range])))
                }
            }
        } catch {
            Logger.service.error("Failed to find placeholders in string: \(string)")
        }

        return ranges
    }
}

