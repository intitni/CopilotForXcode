# Development

## Targets 

### Copilot for Xcode

Copilot for Xcode is the app containing both the XPCService and the editor extension.

### EditorExtension

As its name suggests, the editor extension. Since an editor extension must be sandboxed, it will need to talk to a trusted non-sandboxed XPCService to break out the limitations. The identifier of the XPCService must be listed under `com.apple.security.temporary-exception.mach-lookup.global-name` in entitlements.

### XPCService

The XPCService is a program that runs in the background and does basically everything. It redirects the requests from EditorExtension to `CopilotService` and returns the updated code back to the extension.

Since the Xcode source editor extension only allows its commands to be triggered manually, the XPCService has to use Apple Scripts to trigger the menu items to generate real-time suggestions.

The XPCService is also using a lot of Apple Script tricks to get the file paths and project/workspace paths of the active Xcode window because Xcode is not providing this information.

## Building and Archiving the App

This project contains a Git submodule `copilot.vim`, so you will have to initialize the submodule or download it from [copilot.vim](https://github.com/github/copilot.vim).

Then archive the target Copilot for Xcode.

## Testing Extension

### Testing Real-time Suggestions Commands

Testing Real-time Suggestions is a little bit different because the Apple Script can't find the commands when debugging the extension in Xcode. Instead, you will have to archive the debug version of the app, run the XPCService target simultaneously and use them against each other.

### Testing Other Commands

Just run both the XPCService and the EditorExtension Target. 

## App Versioning

The app version and all targets' version in controlled by `Version.xcconfig`.
