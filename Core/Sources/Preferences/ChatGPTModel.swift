import Foundation

public enum ChatGPTModel: String {
    case textDavinci003 = "text-davinci-003"

    case textCurie001 = "text-curie-001"

    case textBabbage001 = "text-babbage-001"

    case textAda001 = "text-ada-001"

    case codeDavinci002 = "code-davinci-002"

    case codeCushman001 = "code-cushman-001"

    case textDavinciEdit001 = "text-davinci-edit-001"

    case gpt35Turbo = "gpt-3.5-turbo"

    case gpt35Turbo0301 = "gpt-3.5-turbo-0301"
}

extension ChatGPTModel: CaseIterable {}
