# Architecture

## Overview

ChatGPT Usage Bar is a Swift Package with three targets:

- `ChatGPTUsageCore`: domain models and deterministic logic.
- `ChatGPTUsageBar`: the macOS menu bar executable.
- `ChatGPTUsageCoreCheck`: executable regression checks for the core target.

The app intentionally keeps account passwords out of its data files. Each account receives an isolated `WKWebsiteDataStore`, which preserves that account's local WebKit session.

## Source Layout

```text
Sources/
  ChatGPTUsageCore/
    Accounts/    Account profiles, login state, subscriptions, ordering
    Refresh/     Automatic refresh intervals and reset-time scheduling
    Settings/    Persisted app settings, themes, app version text, footer quotes
    Usage/       Usage snapshots and visible-text parsing
  ChatGPTUsageBar/
    Accounts/    Account editor
    App/         App entry point and runtime information
    Dashboard/   Main dashboard, account cards, empty state, drag support
    Settings/    Settings screen and automatic-refresh controls
    Shared/      Shared static glass styling and theme palette
    Store/       Local persistence and account mutations
    WebKit/      Login windows and background official-page reading
  ChatGPTUsageCoreCheck/
    main.swift   Core regression checks
```

## Data Flow

1. `UsageStore` loads account profiles and settings from `~/Library/Application Support/ChatGPTUsageBar/`.
2. `DashboardView` renders account cards and sends refresh actions to `WebKitUsageController`.
3. `WebKitUsageController` opens the official Codex Analytics page in the account's isolated WebKit session.
4. `UsageSnapshotParser` extracts visible 5-hour and weekly cards while ignoring analytics filter controls.
5. The controller opens the official Billing settings page to read the visible renewal text, then navigates the background web view back to Analytics.
6. `UsageStore` persists successful snapshots. A transient failed read preserves the last valid usage values and records an error. When old usage values remain available, the account card shows a compact stale-data warning and exposes detailed diagnostics through its tooltip.

## Refresh Model

There are three independent refresh triggers:

- Manual refresh for one account or all logged-in accounts.
- User-configured periodic refresh for the current account or all logged-in accounts.
- Reset-time refresh based on the parsed 5-hour or weekly reset timestamp.

The reset-time scheduler performs one catch-up refresh when the app starts after a missed reset boundary. Accounts without a detected login session are skipped.

## Packaging

`Scripts/package-app.sh` builds the release executable and assembles:

```text
.build/release/ChatGPTUsageBar.app
```

The bundled `.app` mode is required for macOS launch-at-login registration. Running with `swift run ChatGPTUsageBar` remains useful during development but depends on the terminal process.

## Privacy Boundary

- Account passwords are never stored by the app.
- Browser Cookie stores are not imported.
- Each configured account uses an isolated WebKit data store.
- Usage and subscription information is read from official pages visible to that signed-in account.
