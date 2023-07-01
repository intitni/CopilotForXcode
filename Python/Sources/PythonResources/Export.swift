import Foundation

class BundleFinder {}

let containingBundle: Bundle? = {
    if Bundle.main.path(forResource: "site-packages", ofType: nil) != nil {
        return Bundle.main
    }
    
    if Bundle.main.bundlePath.contains("Contents/Developer/Platforms") {
        // unit tests
        let bundle = Bundle(for: BundleFinder.self)
        let path = bundle.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("CopilotForXcodeExtensionService.app").path
        return Bundle(path: path)
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

