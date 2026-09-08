# Development

## Targets 

### Copilot for Xcode

Copilot for Xcode is the host app containing both the XPCService and the editor extension. It provides the settings UI.

### EditorExtension

As its name suggests, the Xcode source editor extension. Its sole purpose is to forward editor content to the XPCService for processing, and update the editor with the returned content. Due to the sandboxing requirements for editor extensions, it has to communicate with a trusted, non-sandboxed XPCService (CommunicationBridge and ExtensionService) to bypass the limitations. The XPCService service name must be included in the `com.apple.security.temporary-exception.mach-lookup.global-name` entitlements.

### ExtensionService

The `ExtensionService` is a program that operates in the background. All features are implemented in this target. 

### CommunicationBridge

It's responsible for maintaining the communication between the Copilot for Xcode/EditorExtension and ExtensionService.

### Core and Tool

Most of the logics are implemented inside the package `Core` and `Tool`.

- The `Service` contains the implementations of the ExtensionService target.
- The `HostApp` contains the implementations of the Copilot for Xcode target.

## Building and Archiving the App

1. Copy `Local.xcconfig.example` to `Local.xcconfig` and set `DEVELOPMENT_TEAM` to your Apple Developer Team ID. `Local.xcconfig` is gitignored; `Config.xcconfig` and `Config.debug.xcconfig` include it with `#include?`.
2. Update the xcconfig files, `bridgeLaunchAgent.plist`, and `Tool/Configs/Configurations.swift` if you are changing identifiers.
3. Build or archive the Copilot for Xcode target.

## Testing Source Editor Extension and Service

On this fork, run the `Copilot for Xcode Debug` scheme. That is enough for the host, CommunicationBridge, and ExtensionService: the host registers a launch agent at `~/Library/LaunchAgents/dev.com.intii.CopilotForXcode.CommunicationBridge.plist` and loads it with `launchctl bootstrap`. CommunicationBridge is owned by that launch agent — do **not** Run the `CommunicationBridge` or `ExtensionService` schemes. A second ExtensionService from another bundle path is not reused. Keep only one Dev instance running at a time.

The `.appex` still follows Apple's editor-extension workflow. Run the `EditorExtension` scheme when you need to debug the source editor extension itself. See [Testing Your Source Editor Extension](https://developer.apple.com/documentation/xcodekit/testing_your_source_editor_extension).

To uninstall the agent, use **General › Remove Launch Agent** in the host app, or:

```bash
launchctl bootout gui/$(id -u)/dev.com.intii.CopilotForXcode.CommunicationBridge
```

To debug ExtensionService, use **Debug › Attach to Process…** on the running `CopilotForXcodeExtensionService` process.

## SwiftUI Previews

Looks like SwiftUI Previews are not very happy with Objective-C packages when running with app targets. To use previews, please switch schemes to the package product targets.

## Unit Tests

To run unit tests, just run test from the `Copilot for Xcode` target.

For new tests, they should be added to the `TestPlan.xctestplan`.

## Chat Plugins

To create a chat plugin, please use the `TerminalChatPlugin` as an example. You should add your plugin to the target `ChatPlugin` and register it in `ChatService`.

## Code Style

We use SwiftFormat to format the code.

The source code mostly follows the [Ray Wenderlich Style Guide](https://github.com/raywenderlich/swift-style-guide) very closely with the following exception:

- Use the Xcode default of 4 spaces for indentation.

## App Versioning

The app version and all targets' version in controlled by `Version.xcconfig`.
