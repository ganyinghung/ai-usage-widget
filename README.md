# AI Usage Widget for macOS

A small, native desktop card for Claude and OpenAI Codex subscription usage. It shows the current 5-hour and weekly windows, their reset times, and the highest usage percentage in the menu bar.

![Native macOS](https://img.shields.io/badge/macOS-13%2B-black)
![No dependencies](https://img.shields.io/badge/dependencies-none-34c759)

## What it reads

- **Codex:** live account-wide limits from the official Codex App Server (`account/rateLimits/read`). If App Server is unavailable, the app falls back to the latest `rate_limits` snapshot under `~/.codex/sessions` or `~/.codex/archived_sessions` and marks it stale.
- **Claude:** the existing Claude Code OAuth credential from macOS Keychain (or `~/.claude/.credentials.json`) and the `https://api.anthropic.com/api/oauth/usage` endpoint used by Claude Code's `/usage` screen.

Credentials are read only when refreshing. They are never logged or copied into the widget cache. The cache contains only percentages, reset dates, and provider labels at `~/Library/Application Support/AIUsageWidget/usage.json`.

## Build and run

Requirements: macOS 13 or newer and Xcode Command Line Tools (or Xcode).

For live Codex readings, install/sign in to Codex or the ChatGPT desktop app. The widget discovers the official App Server bundled with either installation; it never reads or stores the Codex access token itself.

```sh
./scripts/install.sh
open "dist/AI Usage Widget.app"
```

The app stays out of the Dock. Drag the card anywhere on the desktop; use the gauge icon in the menu bar to hide it, show it, refresh, or quit. It refreshes every five minutes. The first Claude refresh may show a macOS Keychain permission prompt—choose **Always Allow** if you want automatic refreshes.

For useful readings, sign into each provider at least once. Codex usage from other devices or clients appears on the next five-minute App Server refresh. If a provider is unavailable, the card explains what is missing while the other provider continues to work.

## Is this a “real” Mac desktop widget?

This version is a lightweight desktop-level `NSPanel`, which is more practical for developer tooling: it can read local CLI files, use Keychain, refresh on demand, and remain visible across Spaces. A WidgetKit extension can also be added for macOS Sonoma's Notification Center/Desktop widget gallery, but WidgetKit cannot directly read arbitrary CLI files or Keychain items; it needs this companion app to fetch and share snapshots.

## Test

```sh
swift test
```

The project uses only Swift, SwiftUI, AppKit, Foundation, and Security—no third-party packages or telemetry.
