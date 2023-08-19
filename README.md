# Copilot for Xcode <img alt="Logo" src="/AppIcon.png" align="right" height="50">

![Screenshot](/Screenshot.png)

Copilot for Xcode is an Xcode Source Editor Extension that provides GitHub Copilot, Codeium and ChatGPT support for Xcode.

<a href="https://www.buymeacoffee.com/intitni" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" style="height: 60px !important;width: 217px !important;" ></a>

[Get a Plus License Key to unlock more features and support this project](https://intii.lemonsqueezy.com)

## Features

- Code Suggestions (powered by GitHub Copilot and Codeium).
- Chat (powered by OpenAI ChatGPT).
- Prompt to Code (powered by OpenAI ChatGPT).
- Custom Commands to extend Chat and Prompt to Code.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Permissions Required](#permissions-required)
- [Installation and Setup](#installation-and-setup)
  - [Install](#install)
  - [Enable the Extension](#enable-the-extension)
  - [Granting Permissions to the App](#granting-permissions-to-the-app)
  - [Setting Up Key Bindings](#setting-up-key-bindings)
  - [Setting Up GitHub Copilot](#setting-up-github-copilot)
  - [Setting Up Codeium](#setting-up-codeium)
  - [Setting Up OpenAI API Key](#setting-up-openai-api-key)
  - [Managing `CopilotForXcodeExtensionService.app`](#managing-copilotforxcodeextensionserviceapp)
- [Update](#update)
- [Feature](#feature)
- [Plus Features](#plus-features)
- [Limitations](#limitations)
- [License](#license)

For frequently asked questions, check [FAQ](https://github.com/intitni/CopilotForXcode/wiki/Frequently-Asked-Questions).

For development instruction, check [Development.md](DEVELOPMENT.md).

For more information, check the [wiki](https://github.com/intitni/CopilotForXcode/wiki)

## Prerequisites

- Public network connection.

For suggestion features:

- For GitHub Copilot users:
  - [Node](https://nodejs.org/) installed to run the Copilot LSP.
  - Active GitHub Copilot subscription.
- For Codeium users:
  - Active Codeium account.

For chat and prompt to code features:

- Valid OpenAI API key.

## Permissions Required

- Folder Access
- Accessibility API

> If you are concerned about key logging and cannot trust the binary, we recommend examining the code and [building it yourself](DEVELOPMENT.md). To address any concerns, you can specifically search for `CGEvent.tapCreate`, `AXObserver`, `AX___` within the code.

## Installation and Setup

### Install

You can install it via [Homebrew](http://brew.sh/):

```bash
brew install --cask copilot-for-xcode
```

Or install it manually, by downloading the `Copilot for Xcode.app` from the latest [release](https://github.com/intitni/CopilotForXcode/releases), and extract it to the Applications folder.

Open the app, the app will create a launch agent to setup a background running Service that does the real job.

### Enable the Extension

Enable the extension in `System Settings.app`.

From the Apple menu located in the top-left corner of your screen click `System Settings`. Navigate to `Privacy & Security` then toward the bottom click `Extensions`. Click `Xcode Source Editor` and tick `Copilot`.

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
| Accept Suggestions  | `⌥}` (Or accept with Tab if Plus license is available) |
| Reject Suggestion   | `⌥{`                                                   |
| Next Suggestion     | `⌥>`                                                   |
| Previous Suggestion | `⌥<`                                                   |
| Open Chat           | `⌥"`                                                   |
| Explain Selection   | `⌥\|`                                                  |

Essentially using `⌥⇧` as the "access" key combination for all bindings.

Another convenient method to access commands is by using the `⇧⌘/` shortcut to search for a command in the menu bar.

### Setting Up GitHub Copilot

1. In the host app, switch to the service tab and click on GitHub Copilot to access your GitHub Copilot account settings.
2. Click "Install" to install the language server.
3. Optionally setup the path to Node. The default value is just `node`, Copilot for Xcode.app will try to find the Node from the PATH available in a login shell. If your Node is installed somewhere else, you can run `which node` from terminal to get the path.
4. Click "Sign In", and you will be directed to a verification website provided by GitHub, and a user code will be pasted into your clipboard.
5. After signing in, go back to the app and click "Confirm Sign-in" to finish.
6. Go to "Feature - Suggestion" and update the feature provider to "GitHub Copilot".

The installed language server is located at `~/Library/Application Support/com.intii.CopilotForXcode/GitHub Copilot/executable/`.

### Setting Up Codeium

1. In the host app, switch to the service tab and click Codeium to access the Codeium account settings.
2. Click "Install" to install the language server.
3. Click "Sign In", and you will be directed to codeium.com. After signing in, a token will be presented. You will need to paste the token back to the app to finish signing in.
4. Go to "Feature - Suggestion" and update the feature provider to "Codeium".

> The key is stored in the keychain. When the helper app tries to access the key for the first time, it will prompt you to enter the password to access the keychain. Please select "Always Allow" to let the helper app access the key.

The installed language server is located at `~/Library/Application Support/com.intii.CopilotForXcode/Codeium/executable/`.

### Setting Up OpenAI API Key

1. In the host app, click OpenAI to enter the OpenAI account settings.
2. Enter your api key to the text field.

### Managing `CopilotForXcodeExtensionService.app`

This app runs whenever you open `Copilot for Xcode.app` or `Xcode.app`. You can quit it with its menu bar item that looks like a steering wheel.

You can also set it to quit automatically when the above 2 apps are closed.

## Update

If the app was installed via Homebrew, you can update it by running:

```bash
brew upgrade --cask copilot-for-xcode
```

Alternatively, You can use the in-app updater or download the latest version manually from the latest [release](https://github.com/intitni/CopilotForXcode/releases).

After updating, please restart Xcode to allow the extension to reload.

If you are upgrading from a version lower than **0.7.0**, please run `Copilot for Xcode.app` at least once to let it set up the new launch agent for you and re-grant the permissions according to the new rules.

If you find that some of the features are no longer working, please first try regranting permissions to the app.

## Feature

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
- Real-time Suggestions: Call only by Copilot for Xcode. When suggestions are successfully fetched, Copilot for Xcode will run this command to present the suggestions.
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
|  `⇧↩︎`   | Add new line.                                                                                       |
|  `⇧⌘]`   | Move to next tab                                                                                    |
|  `⇧⌘[`   | Move to previous tab                                                                                |

#### Chat Scope

The chat panel allows for chat scope to temporarily control the context of the conversation for the latest message. To use a scope, simply prefix the message with `@scope`.

|  Scope  | Description                                                                              |
| :-----: | ---------------------------------------------------------------------------------------- |
| `@file` | Includes the metadata of the editing document and line annotations in the system prompt. |
| `@code` | Includes the focused/selected code and everything from `@file` in the system prompt.     |
| `@web`  | Allow the bot to search on Bing or query from a web page                                 |

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
|        `/math`         | Solves a math problem in natural language                                                                                                 |
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

#### Commands

- Prompt to Code: Open a prompt to code window, where you can use natural language to write or edit selected code.

### Custom Commands

You can create custom commands that run Chat and Prompt to Code with personalized prompts. These commands are easily accessible from both the Xcode menu bar and the context menu of the circular widget. There are 3 types of custom commands:

- Prompt to Code: Run Prompt to Code with the selected code, and update or write the code using the given prompt, if provided. You can provide additional information through the extra system prompt field.
- Send Message: Open the chat window and immediately send a message, if provided. You can provide more information through the extra system prompt field.
- Custom Chat: Open the chat window and immediately send a message, if provided. You can overwrite the entire system prompt through the system prompt field.
- Single Round Dialog: Send a message to a temporary chat. Useful when you want to run a terminal command with `/run`.

For Send Message, Single Round Dialog and Custom Chat commands, you can use the following template arguments:

| Argument                      | Description                                    |
| ----------------------------- | ---------------------------------------------- |
| `{{selected_code}}`           | The currently selected code in the editor.     |
| `{{active_editor_language}}`  | The programming language of the active editor. |
| `{{active_editor_file_url}}`  | The URL of the active file in the editor.      |
| `{{active_editor_file_name}}` | The name of the active file in the editor.     |

## Plus Features

The pre-built binary contains a set of exclusive features that can only be accessed with a Plus license key. To obtain a license key, please visit [this link](https://intii.lemonsqueezy.com).

These features are included in another repo, and are not open sourced.

The currently available Plus features include:

- Tab to accept suggestions.
- Persisted chat panel.
- Browser tab in chat panel.
- Unlimited custom commands.

Since the app needs to manage license keys, it will send network request to `https://copilotforxcode-license.intii.com`,

- when you activate the license key
- when you deactivate the license key
- when you open the host app or the service app if a license key is available
- every 24 hours if a license key is available

The request contains only the license key, the email address (only on activation), and an instance id. You are free to MITM the request to see what data is sent.

## Limitations

- The extension uses some dirty tricks to get the file and project/workspace paths. It may fail, it may be incorrect, especially when you have multiple Xcode windows running, and maybe even worse when they are in different displays. I am not sure about that though.

## License

Please check [LICENSE](LICENSE) for details.

