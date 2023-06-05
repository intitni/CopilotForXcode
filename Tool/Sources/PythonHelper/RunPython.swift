import Foundation
import PythonKit

public var gilStateEnsure: (() -> Any)!
public var gilStateRelease: ((Any) -> Void)!
func gilStateGuard<T>(_ closure: @escaping () throws -> T) throws -> T {
    let state = gilStateEnsure()
    do {
        let result = try closure()
        gilStateRelease(state)
        return result
    } catch {
        gilStateRelease(state)
        throw error
    }
}

let pythonQueue = DispatchQueue(label: "Python Queue")

public func runPython<T>(
    usePythonThread: Bool = false,
    _ closure: @escaping () throws -> T
) throws -> T {
    if usePythonThread {
        return try PythonThread.shared.runPythonAndWait {
            return try gilStateGuard {
                try closure()
            }
        }
    } else {
        return try gilStateGuard {
            try closure()
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

