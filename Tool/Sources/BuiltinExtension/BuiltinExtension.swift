import ChatTab
import CopilotForXcodeKit
import Foundation
import Preferences

public protocol BuiltinExtension: CopilotForXcodeExtensionCapability {
    /// An id that let the extension manager determine whether the extension is in use.
    var suggestionServiceId: BuiltInSuggestionFeatureProvider { get }

    /// All chat builders provided by this extension.
    var chatTabTypes: [any ChatTab.Type] { get }

    /// It's usually called when the app is about to quit,
    /// you should clean up all the resources here.
    func terminate()
}

// MARK: - Default Implementation

public extension BuiltinExtension {
    var chatTabTypes: [any ChatTab.Type] { [] }
}

