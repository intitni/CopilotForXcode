import Foundation
import PythonHelper
import PythonKit

public struct RecursiveCharacterTextSplitter: TextSplitter {
    public var separators: [String]
    public var chunkSize: Int
    public var chunkOverlap: Int
    
    public init(
        separators: [String] = ["\n\n", "\n", " ", ""],
        chunkSize: Int = 4000,
        chunkOverlap: Int = 200
    ) {
        self.separators = separators
        self.chunkSize = chunkSize
        self.chunkOverlap = chunkOverlap
    }

    public func split(text: String) async throws -> [String] {
        try await runPython {
            let text_splitter = try Python.attemptImportOnPythonThread("langchain.text_splitter")
            let PythonRecursiveCharacterTextSplitter = text_splitter.RecursiveCharacterTextSplitter
            let splitter = PythonRecursiveCharacterTextSplitter(
                separators: separators,
                chunk_size: chunkSize,
                chunk_overlap: chunkOverlap
//                length_function: PythonFunction({ object in
//                    if let string = String(object) { return string.count }
//                    return 0
//                })
            )
            let result = splitter.split_text(text)
            guard let array = [String](result) else { return [] }
            return array
        }
    }
}

