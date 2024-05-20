import Foundation

public final class BuiltinExtensionManager {
    public static let shared: BuiltinExtensionManager = .init()
    private(set) var extensions: [BuiltinExtension] = []
    
    public func setupExtensions(_ extensions: [BuiltinExtension]) {
        self.extensions = extensions
    }
    
    public func terminate() {
        for ext in extensions {
            ext.terminate()
        }
    }
}
