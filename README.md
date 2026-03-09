# 🌙 ForMe

A lightweight macOS menu bar app for personal productivity — combining **task management**, **prayer time tracking**, and a **calendar heatmap**, all in a single popup window.

## Features

- **Menu Bar App** — Lives in the macOS menu bar for quick, distraction-free access.
- **Task Management** — Add, prioritize (Low / Medium / High), complete, and delete tasks with full keyboard navigation.
- **Prayer Times** — Fetches daily prayer schedules (Fajr, Dhuhr, Asr, Maghrib, Isha) via the [Aladhan API](https://aladhan.com/prayer-times-api) with a live countdown to the next prayer.
- **Smart Location** — Automatically detects your location using GPS → IP geolocation → hardcoded fallback.
- **Calendar Heatmap** — Visual overview of completed tasks by day, with priority-colored badges.
- **Keyboard-Driven** — Navigate and manage tasks entirely via keyboard shortcuts.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `↑` `↓` | Navigate tasks |
| `Space` | Complete selected task |
| `⌫` | Delete selected task |
| `⌘1` `⌘2` `⌘3` | Set priority (Low / Medium / High) |
| `⌘D` | Toggle Tasks ↔ Calendar |
| `←` `→` | Navigate days (Calendar) |
| `Esc` | Deselect / Back |

## Tech Stack

- **Swift** + **SwiftUI**
- **SwiftData** for local persistence
- **CoreLocation** + **MapKit** for location services
- macOS 26.2+

## Building

Open `ForMe.xcodeproj` in Xcode and run. No external dependencies required.

## License

This project is for personal use.
