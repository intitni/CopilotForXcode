import Foundation

public protocol ChatGPTFunctionProvider {
    var functionSchemas: [String] { get }
    func function(named: String) -> (any ChatGPTFunction)?
}

public struct NoChatGPTFunctionProvider: ChatGPTFunctionProvider {
    public init() {}

    public var functionSchemas: [String] { [] }
    public func function(named: String) -> (any ChatGPTFunction)? { nil }
}
