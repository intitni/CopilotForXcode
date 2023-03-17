# Copilot for Xcode <img alt="Logo" src="/AppIcon.png" align="right" height="50">

![Screenshot](/Screenshot.png)

Copilot for Xcode is an Xcode Source Editor Extension that provides Github Copilot support for Xcode. It uses the LSP provided through [Copilot.vim](https://github.com/github/copilot.vim/tree/release/copilot/dist) to generate suggestions and displays them as comments or in a separate window.

Thanks to [LSP-copilot](https://github.com/TerminalFi/LSP-copilot) for showing the way to interact with Copilot. And thanks to [LanguageClient](https://github.com/ChimeHQ/LanguageClient) for the Language Server Protocol support in Swift.

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/intitni)

## Table of Contents

- [Prerequisites](#prerequisites)
- [Permissions Required](#permissions-required)
- [Installation and Setup](#installation-and-setup)
  - [Install](#install)
  - [Sign In GitHub Copilot](#sign-in-github-copilot)
  - [Granting Permissions to the App](#granting-permissions-to-the-app)
  - [Managing `CopilotForXcodeExtensionService.app`](#managing-copilotforxcodeextensionserviceapp)
- [Update](#update)
- [Commands](#commands)
- [Key Bindings](#key-bindings)
- [Prevent Suggestions Being Committed](#prevent-suggestions-being-committed)
- [Limitations](#limitations)
- [FAQ](#faq)
- [License](#license)


For development instruction, check [Development.md](DEVELOPMENT.md).

## Prerequisites

- [Node](https://nodejs.org/) installed to run the Copilot LSP.
- Public network connection.
- Active GitHub Copilot subscription.  

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

Then set it up with the following steps:

1. Open the app, the app will create a launch agent to setup a background running Service that does the real job.
2. Optionally setup the path to Node. The default value is just `node`, Copilot for Xcode.app will try to find the Node from `/usr/bin:/usr/local/bin`. If your Node is installed somewhere else, you can run `which node` from terminal to get the path.   
3. Enable the extension in `System Settings.app`. 

    From the Apple menu located in the top-left corner of your screen click `System Settings`. Navigate to `Privacy & Security` then toward the bottom click `Extensions`. Click `Xcode Source Editor` and tick `Copilot`.
    
    If you are using macOS Monterey, enter the `Extensions` menu in `System Preferences.app` with its dedicated icon.

### Sign In GitHub Copilot
 
1. In the app, refresh the Copilot status (it may fail for the first time, try at least one more time). 
2. Click "Sign In", and you will be directed to a verification website provided by GitHub, and a user code will be pasted into your clipboard.
3. After signing in, go back to the app and click "Confirm Sign-in" to finish.

### Granting Permissions to the App

The first time the app is open and command run, the extension will ask for the necessary permissions.

Alternatively, you may manually grant the required permissions by navigating to the `Privacy & Security` tab in the `System Settings.app`.

- To grant permissions for the Accessibility API, click `Accessibility`, and drag `CopilotForXcodeExtensionService.app` to the list. You can locate the extension app by clicking `Reveal Extension App in Finder` in the host app.

<img alt="Accessibility API" src="/accessibility_api_permission.png" width="500px">

If you encounter an alert requesting permission that you have previously granted, please remove the permission from the list and add it again to re-grant the necessary permissions.

### Managing `CopilotForXcodeExtensionService.app`

This app runs whenever you open `Copilot for Xcode.app` or `Xcode.app`. You can quit it with its menu bar item that looks like a steering wheel.

You can also set it to quit automatically when the above 2 apps are closed.

## Update 

If the app was installed via Homebrew, you can update it by running:

```bash
brew upgrade --cask copilot-for-xcode
```

Alternatively, You can download the latest version manually from the latest [release](https://github.com/intitni/CopilotForXcode/releases).  

If you are upgrading from a version lower than **0.7.0**, please run `Copilot for Xcode.app` at least once to let it set up the new launch agent for you and re-grant the permissions according to the new rules.

If you want to keep track of the new releases, you can watch the releases of this repo to get notifications about updates.

If you find that some of the features are no longer working, please first try regranting permissions to the app.

## Commands

- Get Suggestions: Get suggestions for the editing file at the current cursor position.
- Next Suggestion: If there is more than one suggestion, switch to the next one.
- Previous Suggestion: If there is more than one suggestion, switch to the previous one.
- Accept Suggestion: Add the suggestion to the code.
- Reject Suggestion: Remove the suggestion comments.
- Toggle Real-time Suggestions: When turn on, Copilot will auto-insert suggestion comments to your code while editing.
- Real-time Suggestions: Call only by Copilot for Xcode. When suggestions are successfully fetched, Copilot for Xcode will run this command to present the suggestions.
- Prefetch Suggestions: Call only by Copilot for Xcode. In the background, Copilot for Xcode will occasionally run this command to prefetch real-time suggestions. 

**About real-time suggestions**

The on/off state is persisted, so be sure to turn it off manually when you no longer want it. When real-time suggestion is turned on, a dot will show up next to the text cursor. 

Whenever you stop typing for a few milliseconds, the app will automatically fetch suggestions for you, you can cancel this by clicking the mouse, or pressing **Escape** or the **arrow keys**.

When a fetch occurs, the dot will play an animation. If you don't see it, your permissions may not be set correctly.

The implementation won't feel as smooth as that of VSCode. The magic behind it is that it will keep calling the command from the menu when you are not typing or clicking the mouse. So it will have to listen to those events, I am not sure if people like it. Hope that next year, Apple can spend some time on Xcode Extensions.  

It will be a better experience if you use the "Floating Widget" mode with real-time suggestions turned on.

## Key Bindings

It looks like there is no way to add default key bindings to commands, but you can set them up in `Xcode settings > Key Bindings`. You can filter the list by typing `copilot` in the search bar.

A [recommended setup](https://github.com/intitni/CopilotForXcode/issues/14) that should cause no conflict is

| Command | Key Binding |
| --- | --- |
| Get Suggestions | `⌥?` |
| Accept Suggestions | `⌥}` |
| Reject Suggestion | `⌥{` |
| Next Suggestion | `⌥>` |
| Previous Suggestion | `⌥<` |

Essentially using `⌥⇧` as the "access" key combination for all bindings.

## Prevent Suggestions Being Committed (in comment mode)

Since the suggestions are presented as comments, they are in your code. If you are not careful enough, they can be committed to your git repo. To avoid that, I would recommend adding a pre-commit git hook to prevent this from happening.

```sh
#!/bin/sh

# Check if the commit message contains the string
if git diff --cached --diff-filter=ACMR | grep -q "/*========== Copilot Suggestion"; then
  echo "Error: Commit contains Copilot suggestions generated by Copilot for Xcode."
  exit 1
fi
```

## Limitations

- The first run of the extension will be slow. Be patient.
- The extension uses some dirty tricks to get the file and project/workspace paths. It may fail, it may be incorrect, especially when you have multiple Xcode windows running, and maybe even worse when they are in different displays. I am not sure about that though.
- The suggestions are presented as C-style comments in comment mode, they may break your code if you are editing a JSON file or something.
- When a real-time suggestion request is triggered, there is a chance that it may briefly block the editor. This can occur at most once for each file after each restart of the extension because the extension needs to initiate real-time suggestion by clicking an item from the menu bar. However, once a command has been executed and some information is cached, the extension will be able to trigger real-time suggestion using a different method.

## FAQ

**Q: The extension doesn't show up in the `Editor` menu.**

> A: Please make sure `Copilot` is turned on in `System Settings.app > Privacy & Security > Extensions > Xcode Source Editor Extension`.

**Q: The extension says it can't connect to the XPC service/helper.**

> A: If you have just updated the app from an old version, make sure you have restarted the XPC Service.
> 
> Please make sure you have set up Launch Agents, try running `launchctl list | grep com.intii` from the terminal, and see if `com.intii.CopilotForXcode.ExtensionService` exists. If not, check `~/Library/LaunchAgents` to see if `com.intii.CopilotForXcode.ExtensionService.plist` exists. If they don't, and the button in the app fails to create them, please try to do it by hand.
> 
> If you are installing multiple versions of the extension on your machine, it's also possible that Xcode is using the older version of the extension.

**Q: The extension complains that it has no access to the Accessibility API**

> A: Please check if the [Accessibility API permission](https://github.com/intitni/CopilotForXcode#granting-permissions-to-the-app) is setup correctly.

**Q: I turned on real-time suggestions, but nothing happens**

> A: Try typing something in the editor and wait for a little while, if you see an animation from the real-time suggestion indicator or the floating widget, that means the real-time suggestion is correctly triggered. 

**Q: I can't cancel real-time suggestions with mouse clicks, or pressing esc.**

> A: Please check if the [Accessibility API and Input Monitoring permission](https://github.com/intitni/CopilotForXcode#granting-permissions-to-the-app) is setup correctly.
    If you have followed the setup instructions as directed, please also consider granting Input Monitoring permissions to the extension app.

**Q: I have signed in my GitHub account, but the app doesn't generate any suggestions.

> A: Please make sure the GitHub Copilot status is `OK`. If it's not, it's likely that your GitHub Copilot subscription is not valid. 

**Q: Will it work in future Xcode updates?**

> A: I don't know. This extension uses many tricks to do its job, and these tricks can break in the future. 

## License 

MIT.
