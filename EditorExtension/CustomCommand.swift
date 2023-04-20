import Client
import CopilotModel
import Foundation
import XcodeKit

class CustomCommand: NSObject, XCSourceEditorCommand, CommandType {
    let name: String
    let identifer: String
    
    init(name: String, identifer: String) {
        self.name = name
        self.identifer = identifer
    }
    
    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let service = try getService()
                if let content = try await service.explainSelection(
                    editorContent: .init(invocation)
                ) {
                    invocation.accept(content)
                }
                completionHandler(nil)
            } catch is CancellationError {
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
