import Foundation
import Python
import PythonKit

@globalActor
public actor PythonActor {
    public static let shared = PythonActor()
}

/// You MUST run every Python code with this function.
///
/// It's important to note that `PythonKit` is not thread safe. You should be careful to not
/// Introduce any racing to avoid crashes.
///
/// The python code will run between PyGILState_Ensure and PyGILState_Release. But I am
/// not sure whether it's the correct thing to do.
@PythonActor
public func runPython<T>(
    _ closure: @escaping () throws -> T
) throws -> T {
    do {
        let gilState = PyGILState_Ensure()
        let result = try closure()
        PyGILState_Release(gilState)

        return result
    } catch let error as PythonError {
        throw ReadablePythonError(error)
    } catch {
        throw error
    }
}

public extension PythonInterface {
    /// Import a package from a thread with larger stack size.
    ///
    /// Sometimes the Python interpreter will crash when importing a package if the stack size
    /// of the thread is too small. For example, `langchain`, `numpy`.
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

