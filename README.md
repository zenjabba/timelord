# DM Time Lord

A free, privacy-first freelance time tracking app for iOS, iPadOS, and Apple Watch.

## Features

- **Timer** — Start/stop/pause with one tap. Live Activity on the lock screen.
- **Timeline** — Visual day view of your time blocks.
- **Clients & Projects** — Organize work with color-coded clients and projects.
- **Multi-Currency** — Bill in USD, EUR, GBP, or any currency your clients use.
- **Reports** — Weekly/monthly summaries with charts and CSV/PDF export.
- **Invoices** — Generate professional invoices from tracked time.
- **iCloud Sync** — Data syncs across devices via CloudKit.
- **Apple Watch** — Start and stop timers from your wrist.
- **Widgets** — Home screen widget and Live Activity support.

## Requirements

- Xcode 16+
- iOS 17.0+
- Swift 6.0

## Setup

1. Clone the repo
2. Open `Timelord.xcodeproj` in Xcode
3. Update the signing team and bundle identifier to your own
4. Build and run

### Bundle IDs

The project uses `com.digitalmonks.timelord.app` as the base bundle ID. To use your own:

- Update the bundle identifier in Xcode project settings for all targets
- Update the iCloud container identifier in the entitlements files
- Update the App Group identifier in the entitlements files

## Project Structure

```
Timelord/           — Main iOS app
TimelordKit/        — Shared framework (models, services)
TimelordWidgets/    — Widget and Live Activity extension
TimelordWatch/      — Apple Watch app
```

## Architecture

- **SwiftUI** with `@Observable` (not ObservableObject)
- **SwiftData** for persistence with CloudKit sync
- **MVVM** pattern throughout
- **Swift 6** strict concurrency

## License

Source-available. See [LICENSE](LICENSE) for details.
