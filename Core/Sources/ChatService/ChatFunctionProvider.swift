import ChatBasic
import Foundation
import OpenAIService

final class ChatFunctionProvider {
    var functions: [any ChatGPTFunction] = []
    
    init() {}
    
    func removeAll() {
        functions = []
    }
    
    func append(functions others: [any ChatGPTFunction]) {
        functions.append(contentsOf: others)
    }
}

extension ChatFunctionProvider: ChatGPTFunctionProvider {
    var functionCallStrategy: OpenAIService.FunctionCallStrategy? {
        nil
    }
}

