import Foundation
import Python
import PythonKit
import PythonHelper

func initializePython() {
    guard let sitePackagePath = Bundle.main.path(forResource: "site-packages", ofType: nil),
          let stdLibPath = Bundle.main.path(forResource: "python-stdlib", ofType: nil),
          let libDynloadPath = Bundle.main.path(
              forResource: "python-stdlib/lib-dynload",
              ofType: nil
          )
    else { return }

    setenv("PYTHONHOME", stdLibPath, 1)
    setenv("PYTHONPATH", "\(stdLibPath):\(libDynloadPath):\(sitePackagePath)", 1)
    
    // Initialize python
    Py_Initialize()
    
    // Immediately release the thread, so that we can ensure the GIL state later.
    // We may not recover the thread because all future tasks will be done in the Python Thread.
    let _ = PyEval_SaveThread()
    
    // Setup GIL state guard.
    PythonHelper.PyGILState_Guard = { closure in
        let gilState = PyGILState_Ensure()
        try closure()
        PyGILState_Release(gilState)
    }

    Task {
        // All future task should run inside runPython.
        try await runPython {
            let sys = Python.import("sys")
            print("Python Version: \(sys.version_info.major).\(sys.version_info.minor)")
        }
    }
}

let queue = DispatchQueue(label: "")

