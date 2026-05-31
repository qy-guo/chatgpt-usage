# Refresh All Accounts And Failure Feedback

## Goal

Add a one-click dashboard action that refreshes every logged-in account, and make failed refresh attempts visible without discarding the last valid usage values.

## Dashboard Interaction

- Add an `arrow.clockwise` icon button immediately to the left of the settings button in the dashboard header.
- Clicking the button refreshes the complete panel data for every logged-in account: Codex Analytics usage and subscription expiry text.
- Accounts that are not logged in are skipped.
- Accounts that are already refreshing are skipped by the existing per-account refresh guard.
- The button keeps a static icon. It is disabled when no logged-in account can be refreshed.
- The tooltip is `刷新所有已登录账号`.

## Refresh Data Flow

`DashboardView` calls a new batch-refresh entry point on `WebKitUsageController`. The controller iterates over the latest accounts from `UsageStore` and delegates each eligible account to the existing `refreshUsage(account:)` method.

This preserves one refresh implementation for manual card refresh, automatic refresh, reset-time refresh, and the new batch refresh action.

## Failure Feedback

The persistence model already preserves prior usage values after a failed Analytics read and records the latest error in `UsageSnapshot.lastError`. The dashboard currently hides that error whenever old usage values still exist.

Update `UsageSummaryView` so that:

- A failed read with prior usage values shows a compact orange message: `刷新失败，当前显示的是上次成功读取的数据`.
- The detailed diagnostic message remains available through a hover tooltip.
- A failed read without prior usage values continues to show the detailed error text inline.
- A later successful Analytics read clears the failure message automatically.

Subscription expiry text is secondary panel data. If its Billing-page read fails while usage succeeds, preserve the previously stored expiry text instead of clearing it. This does not add a separate warning row.

## Scope

- No change to login behavior.
- No change to automatic-refresh schedules.
- No change to reset-time refresh behavior.
- No new persisted settings.
- No popup alert: account-level feedback stays close to the affected card and does not interrupt batch refreshes.

## Verification

- Add a core regression check proving that a successful usage snapshot without newly read Billing text can retain the previous subscription expiry text.
- Keep the existing regression check proving that failed reads preserve previous usage and record `lastError`.
- Run `swift run ChatGPTUsageCoreCheck`.
- Run `swift build`.
- Run `Scripts/package-app.sh` and verify the packaged `.app`.
