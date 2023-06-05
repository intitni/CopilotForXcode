import Foundation
import PythonKit

var gilStateEnsure: (() -> Any)!
var gilStateRelease: ((Any) -> Void)!
func gilStateGuard<T>(_ closure: @escaping () throws -> T) throws -> T {
    let state = gilStateEnsure()
    defer { gilStateRelease(state) }
    do {
        let result = try closure()
        return result
    } catch {
        throw error
    }
}

@MainActor
var isPythonInitialized = false
@MainActor
public func initializePython<GilState, ThreadState>(
    sitePackagePath: String,
    stdLibPath: String,
    libDynloadPath: String,
    Py_Initialize: () -> Void,
    PyEval_SaveThread: () -> ThreadState,
    PyGILState_Ensure: @escaping () -> GilState,
    PyGILState_Release: @escaping (GilState) -> Void
) {
    guard !isPythonInitialized else { return }
    setenv("PYTHONHOME", stdLibPath, 1)
    setenv("PYTHONPATH", "\(stdLibPath):\(libDynloadPath):\(sitePackagePath)", 1)
    setenv("PYTHONIOENCODING", "utf-8", 1)
    isPythonInitialized = true
    // Initialize python
    Py_Initialize()
    // Immediately release the thread, so that we can ensure the GIL state later.
    // We may not recover the thread because all future tasks will be done in the other threads.
    _ = PyEval_SaveThread()
    // Setup GIL state guard.
    gilStateEnsure = { PyGILState_Ensure() }
    gilStateRelease = { gilState in PyGILState_Release(gilState as! GilState) }
}

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

