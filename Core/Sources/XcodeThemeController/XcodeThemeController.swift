import AppKit
import Foundation
import Highlightr
import XcodeInspector

public class XcodeThemeController {
    var syncTriggerTask: Task<Void, Error>?

    public init(syncTriggerTask: Task<Void, Error>? = nil) {
        self.syncTriggerTask = syncTriggerTask
    }

    public func start() {
        let defaultHighlightrThemeManager = Highlightr.themeManager
        Highlightr.themeManager = HighlightrThemeManager(
            defaultManager: defaultHighlightrThemeManager,
            controller: self
        )

        syncXcodeThemeIfNeeded()

        syncTriggerTask?.cancel()
        syncTriggerTask = Task { [weak self] in
            let notifications = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didActivateApplicationNotification)
            for await notification in notifications {
                try Task.checkCancellation()
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                else { continue }
                guard app.isCopilotForXcodeExtensionService else { continue }
                guard let self else { return }
                self.syncXcodeThemeIfNeeded()
            }
        }
    }
}

extension XcodeThemeController {
    func syncXcodeThemeIfNeeded() {
        guard UserDefaults.shared.value(for: \.syncSuggestionHighlightTheme)
            || UserDefaults.shared.value(for: \.syncPromptToCodeHighlightTheme)
            || UserDefaults.shared.value(for: \.syncChatCodeHighlightTheme)
        else { return }
        guard let directories = createSupportDirectoriesIfNeeded() else { return }

        defer {
            UserDefaults.shared.set(
                Date().timeIntervalSince1970,
                for: \.lastSyncedHighlightJSThemeCreatedAt
            )
        }

        let xcodeUserDefaults = UserDefaults(suiteName: "com.apple.dt.Xcode")!

        if let darkThemeName = xcodeUserDefaults
            .value(forKey: "XCFontAndColorCurrentDarkTheme") as? String
        {
            syncXcodeThemeIfNeeded(
                xcodeThemeName: darkThemeName,
                light: false,
                in: directories.themeDirectory
            )
        }

        if let lightThemeName = xcodeUserDefaults
            .value(forKey: "XCFontAndColorCurrentTheme") as? String
        {
            syncXcodeThemeIfNeeded(
                xcodeThemeName: lightThemeName,
                light: true,
                in: directories.themeDirectory
            )
        }
    }

    func syncXcodeThemeIfNeeded(
        xcodeThemeName: String,
        light: Bool,
        in directoryURL: URL
    ) {
        let targetName = light ? "highlightjs-light" : "highlightjs-dark"
        guard let xcodeThemeURL = locateXcodeTheme(named: xcodeThemeName) else { return }
        let targetThemeURL = directoryURL.appendingPathComponent(targetName)
        let lastSyncTimestamp = UserDefaults.shared
            .value(for: \.lastSyncedHighlightJSThemeCreatedAt)

        let shouldSync = {
            if light, UserDefaults.shared.value(for: \.lightXcodeTheme) == nil { return true }
            if !light, UserDefaults.shared.value(for: \.darkXcodeTheme) == nil { return true }
            if light, xcodeThemeName != UserDefaults.shared.value(for: \.lightXcodeThemeName) {
                return true
            }
            if !light, xcodeThemeName != UserDefaults.shared.value(for: \.darkXcodeThemeName) {
                return true
            }
            if !FileManager.default.fileExists(atPath: targetThemeURL.path) { return true }

            let xcodeThemeFileUpdated = {
                guard let xcodeThemeModifiedDate = try? xcodeThemeURL
                    .resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                else { return true }
                return xcodeThemeModifiedDate.timeIntervalSince1970 > lastSyncTimestamp
            }()

            if xcodeThemeFileUpdated { return true }

            return false
        }()

        if shouldSync {
            do {
                let theme = try XcodeTheme(fileURL: xcodeThemeURL)
                let highlightrTheme = theme.asHighlightJSTheme()
                try highlightrTheme.write(to: targetThemeURL, atomically: true, encoding: .utf8)

                Task { @MainActor in
                    if light {
                        UserDefaults.shared.set(xcodeThemeName, for: \.lightXcodeThemeName)
                        UserDefaults.shared.set(.init(theme), for: \.lightXcodeTheme)
                        UserDefaults.shared.set(
                            .init(theme.plainTextColor.storable),
                            for: \.codeForegroundColorLight
                        )
                        UserDefaults.shared.set(
                            .init(theme.backgroundColor.storable),
                            for: \.codeBackgroundColorLight
                        )
                    } else {
                        UserDefaults.shared.set(xcodeThemeName, for: \.darkXcodeThemeName)
                        UserDefaults.shared.set(.init(theme), for: \.darkXcodeTheme)
                        UserDefaults.shared.set(
                            .init(theme.plainTextColor.storable),
                            for: \.codeForegroundColorDark
                        )
                        UserDefaults.shared.set(
                            .init(theme.backgroundColor.storable),
                            for: \.codeBackgroundColorDark
                        )
                    }
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }

    func locateXcodeTheme(named name: String) -> URL? {
        if let customThemeURL = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("Developer/Xcode/UserData/FontAndColorThemes")
            .appendingPathComponent(name),
            FileManager.default.fileExists(atPath: customThemeURL.path)
        {
            return customThemeURL
        }

        let xcodeURL: URL? = {
            // Use the latest running Xcode
            if let running = XcodeInspector.shared.latestActiveXcode?.bundleURL {
                return running
            }
            // Use the main Xcode.app
            let proposedXcodeURL = URL(fileURLWithPath: "/Applications/Xcode.app")
            if FileManager.default.fileExists(atPath: proposedXcodeURL.path) {
                return proposedXcodeURL
            }
            // Look for an Xcode.app
            if let applicationsURL = FileManager.default.urls(
                for: .applicationDirectory,
                in: .localDomainMask
            ).first {
                struct InfoPlist: Codable {
                    var CFBundleIdentifier: String
                }

                let appBundleIdentifier = "com.apple.dt.Xcode"
                let appDirectories = try? FileManager.default.contentsOfDirectory(
                    at: applicationsURL,
                    includingPropertiesForKeys: [],
                    options: .skipsHiddenFiles
                )
                for appDirectoryURL in appDirectories ?? [] {
                    let infoPlistURL = appDirectoryURL.appendingPathComponent("Contents/Info.plist")
                    if let data = try? Data(contentsOf: infoPlistURL),
                       let infoPlist = try? PropertyListDecoder().decode(
                           InfoPlist.self,
                           from: data
                       ),
                       infoPlist.CFBundleIdentifier == appBundleIdentifier
                    {
                        return appDirectoryURL
                    }
                }
            }
            return nil
        }()

        if let url = xcodeURL?
            .appendingPathComponent("Contents/SharedFrameworks/DVTUserInterfaceKit.framework")
            .appendingPathComponent("Versions/A/Resources/FontAndColorThemes")
            .appendingPathComponent(name),
            FileManager.default.fileExists(atPath: url.path)
        {
            return url
        }

        return nil
    }

    func createSupportDirectoriesIfNeeded() -> (supportDirectory: URL, themeDirectory: URL)? {
        guard let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent(
            Bundle.main
                .object(forInfoDictionaryKey: "APPLICATION_SUPPORT_FOLDER") as! String
        ) else {
            return nil
        }

        let themeURL = supportURL.appendingPathComponent("Themes")

        do {
            if !FileManager.default.fileExists(atPath: supportURL.path) {
                try FileManager.default.createDirectory(
                    at: supportURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            if !FileManager.default.fileExists(atPath: themeURL.path) {
                try FileManager.default.createDirectory(
                    at: themeURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
        } catch {
            return nil
        }

        return (supportURL, themeURL)
    }
}

