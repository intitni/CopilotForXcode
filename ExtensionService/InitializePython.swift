import Foundation
import Python
import PythonKit

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
    Py_Initialize()
}

