import Client
import CopilotModel
import Foundation
import XcodeKit

class CustomCommand: NSObject, XCSourceEditorCommand, CommandType {
    let name: String
    
    init(name: String) {
        self.name = name
    }
    
    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let service = try getService()
                if let content = try await service.customCommand(
                    name: name,
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
