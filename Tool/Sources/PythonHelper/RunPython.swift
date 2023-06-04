import Foundation
import PythonKit

public var PyGILState_Guard: ((() throws -> Void) throws -> Void)! = nil

let pythonQueue = DispatchQueue(label: "Python Queue")

public func runPython<T>(
    usePythonThread: Bool = false,
    _ closure: @escaping () throws -> T
) async throws -> T {
    return try await withUnsafeThrowingContinuation { con in
        if usePythonThread {
            PythonThread.shared.runPython {
                do {
                    try PyGILState_Guard {
                        con.resume(returning: try closure())
                    }
                } catch let error as PythonError {
                    con.resume(throwing: ReadablePythonError(error))
                } catch {
                    con.resume(throwing: error)
                }
            }
        } else {
            pythonQueue.async {
                do {
                    try PyGILState_Guard {
                        con.resume(returning: try closure())
                    }
                } catch let error as PythonError {
                    con.resume(throwing: ReadablePythonError(error))
                } catch {
                    con.resume(throwing: error)
                }
            }
        }
    }
}

public extension PythonInterface {
    func attemptImportOnPythonThread(_ name: String) throws -> PythonObject {
        try PythonThread.shared.runPythonAndWait {
            let module = try Python.attemptImport(name)
            return module
        }
    }
}

public struct ReadablePythonError: Error, LocalizedError {
    public var error: PythonError

    public init(_ error: PythonError) {
        self.error = error
    }

    public var errorDescription: String? {
        switch error {
        case let .exception(object, _):
            return "\(object)"
        case let .invalidCall(object):
            return "Invalid call: \(object)"
        case let .invalidModule(module):
            return "Invalid module: \(module)"
        }
    }
}



