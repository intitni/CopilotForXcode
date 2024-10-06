# Copilot for Xcode <img alt="Logo" src="/AppIcon.png" align="right" height="50">

![Screenshot](/Screenshot.png)

Copilot for Xcode is an Xcode Source Editor Extension that provides GitHub Copilot, Codeium and ChatGPT support for Xcode.

<a href="https://www.buymeacoffee.com/intitni" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

## Features

- Code Suggestions
- Chat
- Modification
- Custom Commands to extend Chat and Modification.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Permissions Required](#permissions-required)
- [Installation and Setup](#installation-and-setup)
  - [Install](#install)
  - [Enable the Extension](#enable-the-extension)
  - [Granting Permissions to the App](#granting-permissions-to-the-app)
  - [Setting Up Key Bindings](#setting-up-key-bindings)
  - [Setting Up Suggestion Feature](#setting-up-suggestion-feature)
    - [Setting Up GitHub Copilot](#setting-up-github-copilot)
    - [Setting Up Codeium](#setting-up-codeium)
    - [Using Locally Run LLMs](#using-locally-run-llms)
  - [Setting Up Chat Feature](#setting-up-chat-feature)
  - [Managing `CopilotForXcodeExtensionService.app`](#managing-copilotforxcodeextensionserviceapp)
- [Update](#update)
- [Feature](#feature)
- [Limitations](#limitations)
- [License](#license)

For development instruction, check [Development.md](DEVELOPMENT.md).

For more information, check the [Wiki Page](https://copilotforxcode.intii.com/wiki).

## Prerequisites

- Public network connection.

For suggestion features:

- For GitHub Copilot users:
  - [Node](https://nodejs.org/) installed to run the Copilot LSP.
  - Active GitHub Copilot subscription.
- For Codeium users:
  - Active Codeium account.
- Access to other LLMs.

For chat and prompt to code features:

- A valid OpenAI API key.
- Access to other LLMs.

## Permissions Required

- Folder Access
- Accessibility API

> If you are concerned about key logging and cannot trust the binary, we recommend examining the code and [building it yourself](DEVELOPMENT.md). To address any concerns, you can specifically search for `CGEvent.tapCreate`, `AXObserver`, `AX___` within the code.

## Installation and Setup

> The installation process is a bit complicated. Here is a quick overview:
> 
> 1. Install the app into the Applications folder, open it once.
> 2. Enable the source editor extension.
> 3. Grant Accessibility API permission to the extension app.
> 4. Setup accounts and models in the host app.
> 5. Optionally, update the settings of each feature in the host app, and setup keybindings.

### Install

You can install it via [Homebrew](http://brew.sh/):

```bash
brew install --cask copilot-for-xcode
```

Or install it manually, by downloading the `Copilot for Xcode.app` from the latest [release](https://github.com/intitni/CopilotForXcode/releases).

Please make sure the app is inside the Applications folder.

Open the app, the app will create a launch agent to setup a background running Service that does the real job.

### Enable the Extension

Enable the extension in `System Settings.app`.

#### macOS 15
From the Apple menu located in the top-left corner of your screen click `System Settings`. Navigate to `General` then `Login Items & Extensions`. Click `Xcode Source Editor` and tick `Copilot for Xcode`.

#### MacOS 14
From the Apple menu located in the top-left corner of your screen click `System Settings`. Navigate to `Privacy & Security` then toward the bottom click `Extensions`. Click `Xcode Source Editor` and tick `Copilot`.

#### Older Versions
If you are using macOS Monterey, enter the `Extensions` menu in `System Preferences.app` with its dedicated icon.

### Granting Permissions to the App

The first time the app is open and command run, the extension will ask for the necessary permissions.

Alternatively, you may manually grant the required permissions by navigating to the `Privacy & Security` tab in the `System Settings.app`.

- To grant permissions for the Accessibility API, click `Accessibility`, and drag `CopilotForXcodeExtensionService.app` to the list. You can locate the extension app by clicking `Reveal Extension App in Finder` in the host app.

<img alt="Accessibility API" src="/accessibility_api_permission.png" width="500px">

If you encounter an alert requesting permission that you have previously granted, please remove the permission from the list and add it again to re-grant the necessary permissions.

### Setting Up Key Bindings

The extension will work better if you use key bindings.

It looks like there is no way to add default key bindings to commands, but you can set them up in `Xcode settings > Key Bindings`. You can filter the list by typing `copilot` in the search bar.

A [recommended setup](https://github.com/intitni/CopilotForXcode/issues/14) that should cause no conflict is

| Command             | Key Binding                                            |
| ------------------- | ------------------------------------------------------ |
| Accept Suggestions  | `⌥}` or Tab                                            |
| Dismiss Suggestions | Esc                                                    |
| Reject Suggestion   | `⌥{`                                                   |
| Next Suggestion     | `⌥>`                                                   |
| Previous Suggestion | `⌥<`                                                   |
| Open Chat           | `⌥"`                                                   |
| Explain Selection   | `⌥\|`                                                  |

Essentially using `⌥⇧` as the "access" key combination for all bindings.

Another convenient method to access commands is by using the `⇧⌘/` shortcut to search for a command in the menu bar.

#### Setting Up Global Hotkeys

Currently, there is only one global hotkey you can set to show/hide the widgets under the General tab from the host app.

When this hotkey is not set to enabled globally, it will only work when the service app or Xcode is active.

### Setting Up Suggestion Feature

#### Setting Up GitHub Copilot

1. In the host app, navigate to "Service - GitHub Copilot" to access your GitHub Copilot account settings.
2. Click on "Install" to install the language server.
3. Optionally, set up the path to Node. The default value is simply `node`. Copilot for Xcode.app will attempt to locate Node from the following directories: `/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin`.

   If your Node installation is located elsewhere, you can run `which node` from the terminal to obtain the correct path.

   If you are using a node version manager that provides a shim executable, you will need to find the path to the actual executable. Please refer to the FAQ for more information.

4. Click on "Sign In", and you will be redirected to a verification website provided by GitHub. A user code will be copied to your clipboard.
5. After signing in, return to the app and click on "Confirm Sign-in" to complete the process.
6. Go to "Feature - Suggestion" and update the feature provider to "GitHub Copilot".

The installed language server is located at `~/Library/Application Support/com.intii.CopilotForXcode/GitHub Copilot/executable/`.

#### Setting Up Codeium

1. In the host app, navigate to "Service - Codeium" to access the Codeium account settings.
2. Click on "Install" to install the language server.
3. Click on "Sign In" and you will be redirected to codeium.com. After signing in, a token will be provided. You need to copy and paste this token back into the app to complete the sign-in process.
4. Go to "Feature - Suggestion" and update the feature provider to "Codeium".

> The key is stored in the keychain. When the helper app tries to access the key for the first time, it will prompt you to enter the password to access the keychain. Please select "Always Allow" to let the helper app access the key.

The installed language server is located at `~/Library/Application Support/com.intii.CopilotForXcode/Codeium/executable/`.

### Setting Up Chat Feature

1. In the host app, navigate to "Service - Chat Model".
2. Update the OpenAI model or create a new one if necessary. Use the test button to verify the model.
3. Optionally, set up the embedding model in "Service - Embedding Model", which is required for a subset of the chat feature.
4. Go to "Feature - Chat" and update the chat/embedding feature provider with the one you just updated/created.

### Managing `CopilotForXcodeExtensionService.app`

This app runs whenever you open `Copilot for Xcode.app` or `Xcode.app`. You can quit it with its menu bar item that looks like a tentacle.

You can also set it to quit automatically when the above 2 apps are closed.

## Update

You can use the in-app updater or download the latest version manually from the latest [release](https://github.com/intitni/CopilotForXcode/releases).

After updating, please open Copilot for Xcode.app once and restart Xcode to allow the extension to reload.

If you find that some of the features are no longer working, please first try regranting permissions to the app.

## Feature

> Files in gitignore will not receive suggestion. Both chat and prompt to code feature will not have access to them unless you manually select code from them.

### Suggestion

The app can provide real-time code suggestions based on the files you have opened. It's powered by GitHub Copilot and Codeium.

The feature provides two presentation modes:

- Nearby Text Cursor: This mode shows suggestions based on the position of the text cursor.
- Floating Widget: This mode shows suggestions next to the circular widget.

When using the "Nearby Text Cursor" mode, it is recommended to set the real-time suggestion debounce to 0.1.

If you're working on a company project and don't want the suggestion feature to be triggered, you can globally disable it and choose to enable it only for specific projects.

Whenever your code is updated, the app will automatically fetch suggestions for you, you can cancel this by pressing **Escape**.

\*: If a file is already open before the helper app launches, you will need to switch to those files in order to send the open file notification.

#### Commands

- Get Suggestions: Get suggestions for the editing file at the current cursor position.
- Next Suggestion: If there is more than one suggestion, switch to the next one.
- Previous Suggestion: If there is more than one suggestion, switch to the previous one.
- Accept Suggestion: Add the suggestion to the code.
- Reject Suggestion: Remove the suggestion comments.

Commands called by the app:

- Prepare for Real-time Suggestions: Call only by Copilot for Xcode. When suggestions are successfully fetched, Copilot for Xcode will run this command to present the suggestions.
- Prefetch Suggestions: Call only by Copilot for Xcode. In the background, Copilot for Xcode will occasionally run this command to prefetch real-time suggestions.

### Chat

This feature is powered by ChatGPT. Please ensure that you have set up your OpenAI account before using it.

The chat knows the following information:

- The selected code in the active editor.
- The relative path of the file.
- The error and warning labels in the active editor.
- The text cursor location.

There are currently two tabs in the chat panel: one is available shared across Xcode, and the other is only available in the current file.

You can detach the chat panel by simply dragging it away. Once detached, the chat panel will remain visible even if Xcode is inactive. To re-attach it to the widget, click the message bubble button located next to the circular widget.

#### Commands

- Open Chat: Open a chat tab.

#### Keyboard Shortcuts

| Shortcut | Description                                                                                         |
| :------: | --------------------------------------------------------------------------------------------------- |
|   `⌘W`   | Close the chat tab.                                                                                 |
|   `⌘M`   | Minimize the chat, you can bring it back with any chat commands or by clicking the circular widget. |
|  `⇧↩︎`    | Add new line.                                                                                       |
|  `⇧⌘]`   | Move to next tab                                                                                    |
|  `⇧⌘[`   | Move to previous tab                                                                                |

#### Chat Scope

The chat panel allows for chat scope to temporarily control the context of the conversation for the latest message. To use a scope, simply prefix the message with `@scope`.

`@code` is on by default, if `Use @code scope by default in chat context.` is on. Otherwise, `@file` will be on by default.

To use scopes, you can prefix a message with `@code`.

You can use shorthand to represent a scope, such as `@c`, and enable multiple scopes with `@c+web`.

#### Chat Plugins

The chat panel supports chat plugins that may not require an OpenAI API key. For example, if you need to use the `/run` plugin, you just type

```
/run echo hello
```

If you need to end a plugin, you can just type

```
/exit
```

|        Command         | Description                                                                                                                               |
| :--------------------: | ----------------------------------------------------------------------------------------------------------------------------------------- |
|         `/run`         | Runs the command under the project root.                                                                                                  |
|                        | Environment variable: <br>- `PROJECT_ROOT` to get the project root. <br>- `FILE_PATH` to get the editing file path.                       |
|       `/search`        | Search on Bing and summarize the results. You have to setup the Bing Search API in the host app before using it.                          |
|   `/shortcut(name)`    | Run a shortcut from the Shortcuts.app, and use the following message as the input.                                                        |
|                        | If the message is empty, it will use the previous message as input. The output of the shortcut will be printed as a reply from the bot.   |
| `/shortcutInput(name)` | Run a shortcut from the Shortcuts.app, and use the following message as the input.                                                        |
|                        | If the message is empty, it will use the previous message as input. The output of the shortcut will be send to the bot as a user message. |

### Prompt to Code

Refactor existing code or write new code using natural language.

This feature is recommended when you need to update a specific piece of code. Some example use cases include:

- Improving the code's readability.
- Correcting bugs in the code.
- Adding documentation to the code.
- Breaking a large function into smaller functions.
- Generating code with a specific template through custom commands.
- Polishing and correcting grammar and spelling errors in the documentation.
- Translating a localizable strings file.

#### Modification Scope

The chat panel allows for chat scope to temporarily control the context of the conversation for the latest message. To use a scope, simply prefix the message with `@scope`.

To use scopes, you can prefix a message with `@sense`.

You can use shorthand to represent a scope, such as `@sense`, and enable multiple scopes with `@c+web`.

#### Commands

- Write or Modify Code: Open a modification window, where you can use natural language to write or edit selected code.
- Accept Modification: Accept the result of modification.

### Custom Commands

You can create custom commands that run Chat and Modification with personalized prompts. These commands are easily accessible from both the Xcode menu bar and the context menu of the circular widget. There are 3 types of custom commands:

- Modification: Run Modification with the selected code, and update or write the code using the given prompt, if provided. You can provide additional information through the extra system prompt field.
- Send Message: Open the chat window and immediately send a message, if provided. You can provide more information through the extra system prompt field.
- Custom Chat: Open the chat window and immediately send a message, if provided. You can overwrite the entire system prompt through the system prompt field.
- Single Round Dialog: Send a message to a temporary chat. Useful when you want to run a terminal command with `/run`.

You can use the following template arguments in custom commands:

| Argument                      | Description                                    |
| ----------------------------- | ---------------------------------------------- |
| `{{selected_code}}`           | The currently selected code in the editor.     |
| `{{active_editor_language}}`  | The programming language of the active editor. |
| `{{active_editor_file_url}}`  | The URL of the active file in the editor.      |
| `{{active_editor_file_name}}` | The name of the active file in the editor.     |
| `{{clipboard}}`               | The content in clipboard.                      |

## Limitations

- The extension utilizes various tricks to monitor the state of Xcode. It may fail, it may be incorrect, especially when you have multiple Xcode windows running, and maybe even worse when they are in different displays. I am not sure about that though.

## License

Please check [LICENSE](LICENSE) for details.

