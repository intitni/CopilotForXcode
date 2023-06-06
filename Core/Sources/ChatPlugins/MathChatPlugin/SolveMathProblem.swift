import Foundation
import LangChain
import PythonHelper
import PythonKit

func solveMathProblem(_ problem: String) async throws -> String {
//    #if DEBUG
//    let verbose = true
//    #else
//    let verbose = false
//    #endif
//
//    struct E: Error, LocalizedError {
//        var errorDescription: String? {
//            "Failed to parse answer."
//        }
//    }
//
//    let task = Task {
//        try runPython {
//            let langchain = try Python.attemptImportOnPythonThread("langchain")
//            let LLMMathChain = langchain.LLMMathChain
//            let llm = try LangChainChatModel.DynamicChatOpenAI(temperature: 0)
//            let llmMath = LLMMathChain.from_llm(llm, verbose: verbose)
//            let result = try llmMath.run.throwing.dynamicallyCall(withArguments: problem)
//            let answer = String(result)
//            if let answer { return answer }
//
//            throw E()
//        }
//    }
//    
//    return try await task.value
    return "N/A"
}

