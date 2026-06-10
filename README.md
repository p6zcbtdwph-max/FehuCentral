# Productivity Timer

A native macOS menubar app for daily productivity tracking. Built with Swift and SwiftUI — no Xcode required, just the Swift toolchain.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 6](https://img.shields.io/badge/Swift-6-orange) ![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **Day progress** — menubar shows remaining time for your workday at a glance
- **Progress bars** — Day / Week / Month / Year progress in a clean popup
- **Configurable hours** — separate start/end times for weekdays and weekends
- **Notifications** — alerts at 2h, 1h, and 30min before day end
- **Pomodoro timer** — configurable focus (5–90 min) and rest (1–30 min) phases, visible in menubar
- **Custom intervals** — named time blocks (e.g. "Deep Work 09:00–11:00") with live countdown and progress
- **Clipboard manager** — auto-history, saved snippets, search, and password protection
- **Auto-start on login** — via macOS Login Items

## Requirements

- macOS 14 (Sonoma) or later
- Swift toolchain (comes with Xcode Command Line Tools)

## Build & Run

```bash
# Build and install to ~/Applications/
chmod +x build.sh
./build.sh
```

The script compiles a release build, creates the app bundle at `~/Applications/ProductivityTimer.app`, and launches it.

## Auto-start on Login

```bash
chmod +x setup_autostart.sh
./setup_autostart.sh
```

Adds the app to macOS Login Items using `osascript` (no `launchctl` permissions needed).

## Project Structure

```
Sources/KITimer/
├── KITimerApp.swift        # @main entry point, MenuBarExtra
├── TimeManager.swift       # All time calculations, Pomodoro, intervals, notifications
├── TimerInterval.swift     # Codable model for named time blocks
├── ClipboardManager.swift  # Clipboard polling, history, snippets, password safety
├── MainMenuView.swift      # Root view with page navigation
├── PomodoroSection.swift   # Pomodoro UI component
├── IntervalsPage.swift     # Intervals list and editor
├── ClipboardPage.swift     # Clipboard history and snippets UI
├── ProgressRow.swift       # Reusable progress bar row
└── SettingsView.swift      # Settings page
```

## Configuration

All settings are accessible from the gear icon in the popup:

| Setting | Default |
|---|---|
| Workday start | 09:00 |
| Workday end | 18:00 |
| Weekend hours | configurable |
| Pomodoro focus | 25 min |
| Pomodoro rest | 5 min |
| Notifications | 2h, 1h, 30min before day end |

## Clipboard Safety

The clipboard manager automatically skips entries flagged by password managers (`org.nspasteboard.ConcealedType` and similar). You can also pause recording manually at any time.

## License

MIT — see [LICENSE](LICENSE).
