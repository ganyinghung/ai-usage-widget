# AI Usage Widget for macOS

A native WidgetKit widget for Claude and OpenAI Codex subscription usage. The small and medium widgets show the current 5-hour and weekly windows plus their reset times, on the desktop or in Notification Center.

![Native macOS](https://img.shields.io/badge/macOS-14%2B-black)
![No dependencies](https://img.shields.io/badge/dependencies-none-34c759)

The containing app runs silently without a Dock icon, menu bar item, or automatic window. It fetches usage, writes a limited snapshot to an App Group container, and tells WidgetKit when fresh data is available.

## What it reads

- **Codex:** live account-wide limits from the official Codex App Server (`account/rateLimits/read`). If App Server is unavailable, the app falls back to the latest `rate_limits` snapshot under `~/.codex/sessions` or `~/.codex/archived_sessions` and marks it stale.
- **Claude:** the existing Claude Code OAuth credential from macOS Keychain (or `~/.claude/.credentials.json`) and the `https://api.anthropic.com/api/oauth/usage` endpoint used by Claude Code's `/usage` screen.

Credentials are read only by the containing app while refreshing. They are never logged or copied into the widget cache. The shared cache contains only percentages, reset dates, and provider labels.

## Build and run

Requirements: macOS 14 or newer and full Xcode. Open Xcode once and accept its license before building.

1. Open `AIUsageWidget.xcodeproj`.
2. Select the `AIUsageWidget` target, open **Signing & Capabilities**, and choose your Development Team.
3. Do the same for `AIUsageWidgetExtension`.
4. Confirm both targets use the App Group `YOUR_TEAM_ID.com.yhgan.AIUsageWidget`. This macOS-style identifier starts with the Development Team ID. If the signing team changes, replace that prefix in both entitlement files and in `SnapshotStore.appGroupIdentifier`.
5. Run the `AIUsageWidget` scheme once. The first Claude refresh may show a Keychain prompt; choose **Always Allow** for unattended updates.

After signing is configured, a release copy can also be built with:

```sh
./scripts/install.sh
ditto "dist/AI Usage Widget.app" "/Applications/AI Usage Widget.app"
open "/Applications/AI Usage Widget.app"
```

The installed app registers itself as a login item on first launch and then runs silently. Click the widget to open its status window; closing that window leaves background refreshes running. Use the power button in the status window to quit the background app.

For command-line signing without saving a team in the project:

```sh
AI_USAGE_DEVELOPMENT_TEAM=YOUR_TEAM_ID ./scripts/install.sh
```

## Add it to Notification Center

1. Click the date and time in the macOS menu bar to open Notification Center.
2. Click **Edit Widgets** at the bottom.
3. Search for **AI Usage**.
4. Choose the small or medium size and add it.

To place the same widget on the desktop, Control-click the desktop and choose **Edit Widgets**.

Keep the containing app running if you want its five-minute live refresh. WidgetKit also requests a cached timeline update every 15 minutes, but macOS ultimately decides when extension timelines refresh. Launching the background app triggers an immediate provider refresh and widget reload. Clicking the widget opens the optional status window.

## Data flow

The app and extension share `usage.json` through `YOUR_TEAM_ID.com.yhgan.AIUsageWidget`. The extension never reads provider credentials, starts Codex, or scans session logs.

For useful readings, sign into each provider at least once. Codex usage from other devices or clients appears on the next App Server refresh. If a provider is unavailable, the widget preserves the last successful value and marks it stale.

## Test

```sh
swift test
```

The project uses Swift, SwiftUI, WidgetKit, Foundation, and Security, with no third-party packages or telemetry.
