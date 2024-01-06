import GoogleGenerativeAI

public final class GoogleAITokenCounter: TokenCounter {
    let model: GenerativeModel
    
    public init(model: GenerativeModel) {
        self.model = model
    }
    
    public func countToken(text: String) async -> Int {
        (try? await model.countTokens(text))?.totalTokens ?? text.count
    }
}
