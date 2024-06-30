import ChatBasic
import Foundation

public protocol ChatGPTFunctionProvider {
    var functions: [any ChatGPTFunction] { get }
    var functionCallStrategy: FunctionCallStrategy? { get }
}

extension ChatGPTFunctionProvider {
    func function(named: String) -> (any ChatGPTFunction)? {
        functions.first(where: { $0.name == named })
    }
}

public struct NoChatGPTFunctionProvider: ChatGPTFunctionProvider {
    public var functionCallStrategy: FunctionCallStrategy?
    public var functions: [any ChatGPTFunction] { [] }
    public init() {}
}

