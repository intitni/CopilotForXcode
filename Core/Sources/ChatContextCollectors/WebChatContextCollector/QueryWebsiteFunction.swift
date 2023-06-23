import Foundation
import OpenAIService
import Preferences

struct QueryWebsiteFunction: ChatGPTFunction {
    struct Arguments: Codable {
        var query: String
        var urlString: String
    }
    
    struct Result: ChatGPTFunctionResult {
        var relevantTrunks: [String]
        
        var botReadableContent: String {
            // don't forget to remove overlaps
            return ""
        }
    }
    
    var name: String {
        "queryWebsite"
    }
    
    var description: String {
        "Useful for when you need to answer a question using information from a website."
    }
    
    var argumentSchema: JSONSchemaValue {
        return [
            .type: "object",
            .properties: [
                "query": [
                    .type: "string",
                    .description: "things you want to know about the website",
                ],
                "urlString": [
                    .type: "string",
                    .description: "the url of the website"
                ]
            ],
            .required: ["query", "urlString"]
        ]
    }
    
    func message(at phase: OpenAIService.ChatGPTFunctionCallPhase) -> String {
        return ""
    }
    
    func call(arguments: Arguments) async throws -> Result {
        // 1. grab the website content
        // 2. trunk the content
        // 3. embedding and store in memory
        // 4. embedding on the query, then search for relevant trunks, choose the 3 most relevant
        // 5. return the thunks
        
        return .init(relevantTrunks: [])
    }
}
