import AppKit
import Combine
import Foundation
import XcodeInspector

public final class BuiltinExtensionManager {
    public static let shared: BuiltinExtensionManager = .init()
    private(set) var extensions: [BuiltinExtension] = []

    private var cancellable: Set<AnyCancellable> = []

    init() {
        XcodeInspector.shared.$activeApplication.sink { [weak self] app in
            if let app, app.isXcode || app.isExtensionService {
                self?.checkAppConfiguration()
            }
        }.store(in: &cancellable)
    }

    public func setupExtensions(_ extensions: [BuiltinExtension]) {
        self.extensions = extensions
    }

    public func terminate() {
        for ext in extensions {
            ext.terminate()
        }
    }
}

extension BuiltinExtensionManager {
    func checkAppConfiguration() {
        let suggestionFeatureProvider = UserDefaults.shared.value(for: \.suggestionFeatureProvider)
        for ext in extensions {
            let isSuggestionFeatureInUse = suggestionFeatureProvider ==
                .builtIn(ext.suggestionServiceId)
            let isChatFeatureInUse = false
            ext.appConfigurationDidChange(.init(
                suggestionServiceInUse: isSuggestionFeatureInUse,
                chatServiceInUse: isChatFeatureInUse
            ))
        }
    }
}

