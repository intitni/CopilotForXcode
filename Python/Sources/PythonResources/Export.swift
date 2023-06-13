import Foundation

let containingBundle: Bundle? = {
    if Bundle.main.path(forResource: "site-packages", ofType: nil) != nil {
        return Bundle.main
    }
    let path = Bundle.main.bundleURL
        .appendingPathComponent("Contents")
        .appendingPathComponent("Applications")
        .appendingPathComponent("CopilotForXcodeExtensionService.app").path
    
    return Bundle(path: path)
}()

public let sitePackagePath = containingBundle?.path(
    forResource: "site-packages",
    ofType: nil
)
public let stdLibPath = containingBundle?.path(
    forResource: "python-stdlib",
    ofType: nil
)
public let libDynloadPath = containingBundle?.path(
    forResource: "python-stdlib/lib-dynload",
    ofType: nil
)

