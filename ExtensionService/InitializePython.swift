import Foundation
//import Python
import PythonHelper
import PythonKit
import Logger

@MainActor
func initializePython() {
//    guard let sitePackagePath = Bundle.main.path(forResource: "site-packages", ofType: nil),
//          let stdLibPath = Bundle.main.path(forResource: "python-stdlib", ofType: nil),
//          let libDynloadPath = Bundle.main.path(
//              forResource: "python-stdlib/lib-dynload",
//              ofType: nil
//          )
//    else {
//        Logger.service.info("Python is not installed!")
//        return
//    }
//
//    PythonHelper.initializePython(
//        sitePackagePath: sitePackagePath,
//        stdLibPath: stdLibPath,
//        libDynloadPath: libDynloadPath,
//        Py_Initialize: Py_Initialize,
//        PyEval_SaveThread: PyEval_SaveThread,
//        PyGILState_Ensure: PyGILState_Ensure,
//        PyGILState_Release: PyGILState_Release
//    )
//
//    Task {
//        // All future task should run inside runPython.
//        try runPython {
//            let sys = Python.import("sys")
//            Logger.service.info("Python Version: \(sys.version_info.major).\(sys.version_info.minor)")
//        }
//    }
}

