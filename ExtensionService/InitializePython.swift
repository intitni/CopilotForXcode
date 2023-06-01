import Foundation
import Python
import PythonKit

@available( *, deprecated, message: "Testing" )
func initializePython() {
    guard let sitePackagePath = Bundle.main.path(forResource: "site-packages", ofType: nil),
          let stdLibPath = Bundle.main.path(forResource: "python-stdlib", ofType: nil),
          let libDynloadPath = Bundle.main.path(
              forResource: "python-stdlib/lib-dynload",
              ofType: nil
          ) else { return }
    setenv("PYTHONHOME", stdLibPath, 1)
    setenv("PYTHONPATH", "\(stdLibPath):\(libDynloadPath):\(sitePackagePath)", 1)
    Py_Initialize()

    let sys = Python.import("sys")
    print("Python Version: \(sys.version_info.major).\(sys.version_info.minor)")
    print("Python Encoding: \(sys.getdefaultencoding().upper())")
    print("Python Path: \(sys.path)")

    let llms = Python.import("langchain.llms")
    print(llms.OpenAI)
}

