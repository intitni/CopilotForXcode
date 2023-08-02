# Development

## Targets 

### Copilot for Xcode

Copilot for Xcode is the host app containing both the XPCService and the editor extension.

### EditorExtension

As its name suggests, the editor extension. Its sole purpose is to forward editor content to the XPCService for processing, and update the editor with the returned content. Due to the sandboxing requirements for editor extensions, it has to communicate with a trusted, non-sandboxed XPCService to bypass the limitations. The XPCService identifier must be included in the `com.apple.security.temporary-exception.mach-lookup.global-name` entitlements.

### ExtensionService

The `ExtensionService` is a program that operates in the background and performs a wide range of tasks. It redirects requests from the `EditorExtension` to the `CopilotService` and returns the updated code back to the extension, or presents it in a GUI outside of Xcode.

### Core and Tool

Most of the logics are implemented inside the package `Core` and `Tool`.

- The `CopilotService` is responsible for communicating with the GitHub Copilot LSP.
- The `Service` is responsible for handling the requests from the `EditorExtension`, communicating with the `CopilotService`, update the code blocks and present the GUI.
- The `Client` is basically just a wrapper around the XPCService
- The `SuggestionInjector` is responsible for injecting the suggestions into the code. Used in comment mode to present the suggestions, and all modes to accept suggestions.
- The `Environment` contains some swappable global functions. It is used to make testing easier.
- The `SuggestionWidget` is responsible for presenting the suggestions in floating widget mode.

## Building and Archiving the App

1. Update the xcconfig files, launchAgent.plist, and Tool/Configs/Configurations.swift.
2. Build or archive the Copilot for Xcode target.

## Testing Extension

Just run both the `ExtensionService` and the `EditorExtension` Target.

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
