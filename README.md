# Trace

**System-level quick capture for Obsidian on macOS.**

Press `⌘N` anywhere — write to your Daily Note in 2 seconds without leaving your current app.

> *Thought is leverage. Leave a trace.*

## Why

Obsidian plugins only work when Obsidian is open. Every time you switch windows to jot down a thought, your flow breaks. Trace solves this at the OS level — capture without context-switching.

## Features

- **Global hotkey** — `⌘N` (customizable) from any app, no Obsidian window required
- **5 capture zones** — Note / Clip / Link / Task / Project, each maps to a heading in your Daily Note
- **Dual write targets** — Daily Note (append to today's sections) or Inbox (standalone .md files)
- **Pin mode** — continuous capture without closing the panel
- **Native macOS UI** — SwiftUI, not Electron, not a web wrapper
- **Zero network** — pure local, no accounts, no telemetry, your vault stays yours

## How It Works

```
Any App  →  ⌘N  →  Trace Panel  →  ⌘Enter  →  Obsidian Vault
                    (floating)                  (direct .md write)
```

Trace writes directly to your Obsidian vault via `FileManager`. No plugins, no sync conflicts, no middleware.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘N` | Open capture panel (customizable) |
| `⌘Enter` | Save to current zone |
| `⌘⇧Enter` | Append to last entry in same zone |
| `⇧Tab` | Toggle Daily / Inbox mode |
| `Esc` | Dismiss |

## Installation

### From Source

Prerequisites: Xcode 16+ and macOS 13+.

```bash
git clone https://github.com/SamSong1997/Trace.git
cd Trace
./scripts/trace.sh install    # builds and copies to /Applications
./scripts/trace.sh launch-app # start Trace
```

### First Run

1. Click the menu bar icon → **Settings**
2. Set your Obsidian Vault path
3. Adjust the global hotkey if needed
4. Press the hotkey from anywhere — you're set

## Project Structure

```
Sources/Trace/
├── App/          # App lifecycle, menu bar
├── UI/
│   ├── Capture/  # Floating capture panel
│   └── Settings/ # Preferences window
├── Services/     # Hotkey, Daily Note writer, persistence
├── Models/       # Data models
├── Utils/        # Helpers
└── Resources/    # Icons, assets
Tests/TraceTests/ # Unit tests
clients/trace-win/# Windows client (Rust/egui, experimental)
website/          # Product landing page
scripts/          # Build, package, and dev scripts
```

## Tech Stack

- **UI**: SwiftUI + AppKit (macOS native)
- **Global hotkey**: `CGEvent` / `NSEvent.addGlobalMonitorForEvents`
- **File I/O**: `FileManager` direct .md writes, UTF-8
- **Windows port**: Rust + egui (experimental)
- **No backend, no accounts, no network calls**

## Development

```bash
swift build        # compile
swift test         # run tests
./scripts/trace.sh check  # build + test
```

Windows client:

```bash
cd clients/trace-win
cargo run          # run
cargo test         # test
```

## Comparison

| | Trace | QuickAdd (plugin) | Alfred/Raycast |
|---|---|---|---|
| Requires Obsidian open | No | Yes | No |
| Zone-based capture | 5 zones | Configurable | Plain text |
| Direct Daily Note write | Yes | Yes | Via plugin |
| Native macOS UI | Yes | Web render | Yes |
| Runs independently | Yes | No | Yes |

## Prior Art

Trace started as [ObsidianFlashNote](https://github.com/SamSong1997/ObsidianFlashNote), a Hammerspoon-based prototype. The native macOS app is a complete rewrite in SwiftUI.

## License

MIT — see [LICENSE](LICENSE).

## Author

**Sam Song** — [@SamSongAI](https://twitter.com/SamSongAI)

Part of [SOTA Sync](https://sotasync.com).
