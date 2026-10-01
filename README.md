# AI Usage Widget for macOS

A native WidgetKit widget for Claude and OpenAI Codex subscription usage. The small, medium, and large widgets show the current 5-hour and weekly windows plus their reset times, on the desktop or in Notification Center.

![Native macOS](https://img.shields.io/badge/macOS-14%2B-black)
![No dependencies](https://img.shields.io/badge/dependencies-none-34c759)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

The containing app runs silently without a Dock icon, menu bar item, or automatic window. It fetches usage about every five minutes, writes a limited snapshot to an App Group container, and tells WidgetKit when fresh data is available.

## What it reads

- **Codex:** live account-wide limits from the official Codex App Server (`account/rateLimits/read`). If App Server is unavailable, the app falls back to the latest `rate_limits` snapshot under `~/.codex/sessions` or `~/.codex/archived_sessions` and marks it stale.
- **Claude:** the existing Claude Code OAuth credential from macOS Keychain (or `~/.claude/.credentials.json`) and the `https://api.anthropic.com/api/oauth/usage` endpoint used by Claude Code's `/usage` screen.

Credentials are read only by the containing app while refreshing. They are never logged or copied into the widget cache. The shared cache contains only percentages, reset dates, and provider labels.

## Build in Xcode

Requirements: macOS 14 or newer and full Xcode. Open Xcode once and accept its license before building.

1. Open `AIUsageWidget.xcodeproj`.
2. Select the `AIUsageWidget` target, open **Signing & Capabilities**, and choose your Development Team.
3. Do the same for `AIUsageWidgetExtension`.
4. Keep both targets on the same Development Team. The project derives their shared App Group automatically as `$(DEVELOPMENT_TEAM).com.yhgan.AIUsageWidget`; no personal Team ID is stored in the repository.
5. Run the `AIUsageWidget` scheme once. The app starts without opening a window. The first Claude refresh may show a Keychain prompt; choose **Always Allow** for unattended updates.

To open the status window while developing, click an installed widget or run:

```sh
open "aiusagewidget://status"
```

## Install and run without Xcode

Build a Release copy with your Team ID and install it in `/Applications`:

```sh
AI_USAGE_DEVELOPMENT_TEAM=YOUR_TEAM_ID ./scripts/install.sh
/usr/bin/ditto "dist/AI Usage Widget.app" "/Applications/AI Usage Widget.app"
open -gj "/Applications/AI Usage Widget.app"
```

Quit an older installed copy before replacing it. The installed app launches silently and registers itself as a login item on its first launch from `/Applications` or `~/Applications`. macOS may list it under **System Settings → General → Login Items & Extensions**.

The normal controls are:

- Click the widget, or run `open "aiusagewidget://status"`, to open the status window.
- Close the status window to keep background refreshes running.
- Use the power button in the status window to stop the current background process.
- Disable **AI Usage Widget** in Login Items & Extensions if it should not start at the next login.

Opening the application itself starts the updater silently; it intentionally does not show a window.

The command-line Team ID supplies both code signing and the App Group prefix. Xcode users can select their team in **Signing & Capabilities** instead.

## Add it to Notification Center

1. Click the date and time in the macOS menu bar to open Notification Center.
2. Click **Edit Widgets** at the bottom.
3. Search for **AI Usage**.
4. Choose the small, medium, or large size and add it.

To place the same widget on the desktop, Control-click the desktop and choose **Edit Widgets**.

Keep the containing app running if you want its five-minute live refresh. WidgetKit also requests a cached timeline update every 15 minutes, but macOS ultimately decides when extension timelines refresh. Launching the background app triggers an immediate provider refresh and widget reload. Clicking the widget opens the optional status window.

If the containing app is not running, the widget remains visible and shows the last saved snapshot. The extension does not contact either provider itself, so usage values will not become current again until the background app launches.

## Data flow

The app and extension share `usage.json` through the build-time App Group `$(DEVELOPMENT_TEAM).com.yhgan.AIUsageWidget`. The containing app owns provider access and refreshes. The extension only reads this snapshot; it never reads provider credentials, starts Codex, or scans session logs.

For useful readings, sign into each provider at least once. Codex usage from other devices or clients appears on the next App Server refresh. If a provider is unavailable, the widget preserves the last successful value and marks it stale.

## Test

```sh
swift test
```

The project uses Swift, SwiftUI, WidgetKit, Foundation, and Security, with no third-party packages or telemetry. It is available under the [MIT License](LICENSE).
