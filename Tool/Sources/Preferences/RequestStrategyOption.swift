import Foundation

public enum RequestStrategyOption: String, CaseIterable, Codable {
    case `default` = ""
    case naive
    case `continue`
    case codeLlamaFillInTheMiddle
    case codeLlamaFillInTheMiddleWithSystemPrompt
    case anthropic
}
