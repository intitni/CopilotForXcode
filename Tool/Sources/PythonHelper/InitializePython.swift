import Foundation
import Logger
import Python
import PythonKit
import PythonResources

@PythonActor
var isPythonInitialized = false

/// Initialize Python.
@PythonActor
public func initializePython() {
    guard !isPythonInitialized else { return }
    guard let sitePackagePath, let stdLibPath, let libDynloadPath else {
        assertionFailure("Python is not installed! Please run `make setup` to install Python.")
        Logger.python.info("Python is not installed!")
        return
    }
    setenv("PYTHONHOME", stdLibPath, 1)
    setenv("PYTHONPATH", "\(stdLibPath):\(libDynloadPath):\(sitePackagePath)", 1)
    setenv("PYTHONIOENCODING", "utf-8", 1)
    // Initialize python
    Py_Initialize()
    isPythonInitialized = true
    // Immediately release the thread, so that we can ensure the GIL state later.
    _ = PyEval_SaveThread()

    Task {
        // All future task should run inside runPython.
        try runPython {
            let sys = Python.import("sys")
            Logger.service
                .info("Python Version: \(sys.version_info.major).\(sys.version_info.minor)")
        }
    }
}

