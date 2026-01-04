# Aurelia

A powerful macOS clipboard manager with history, search, collections, privacy controls, and menu bar integration.

**Platform:** macOS 15.2+ (Sequoia)
**Swift Version:** 5.0
**Bundle ID:** `SWS.Aurelia`

---

## Features

- **Clipboard History** - Automatically captures text, images, and files
- **Search** - Real-time filtering across all clipboard content
- **Content Type Filters** - Filter by All, Text, Links, Images, or Files
- **Starred Items** - Pin important items to keep them permanently
- **Privacy Controls** - Ignore specific apps (password managers pre-configured)
- **Menu Bar** - Quick access popover with recent items
- **Dark Mode** - Full light/dark mode support
- **Context Menus** - Right-click for Copy, Star, Delete, and more

---

## File Structure

```
Aurelia/
├── AureliaApp.swift                    # App entry point
├── AppDelegate.swift                   # NSApplicationDelegate (menu bar setup)
├── ContentView.swift                   # Main UI with sidebar
├── SettingsView.swift                  # Tabbed settings (General, Privacy)
│
├── Models.swift                        # ClipboardItem, ClipboardContent, ContentTypeFilter
├── AppSettings.swift                   # RetentionPeriod, UserDefaults persistence
│
├── Managers/
│   ├── ClipboardManager.swift          # Clipboard monitoring, filtering (singleton)
│   ├── MenuBarManager.swift            # NSStatusItem, popover
│   ├── PrivacyManager.swift            # Ignored apps, pause monitoring
│   └── HotkeyManager.swift             # Global keyboard shortcut
│
├── StorageManager.swift                # SQLite database + file storage
│
├── Views/
│   ├── MenuBar/
│   │   └── MenuBarPopoverView.swift    # Menu bar popover UI
│   └── Settings/
│       ├── GeneralSettingsView.swift   # Retention, startup, keyboard shortcut
│       └── PrivacySettingsView.swift   # Ignored apps management
│
├── Theme/
│   ├── AureliaTheme.swift              # Semantic colors
│   └── DesignSystem.swift              # Spacing, typography, animations
│
└── Assets.xcassets/
    ├── AppIcon.appiconset/             # App icon
    └── MenuBarIcon.imageset/           # Menu bar icon (template)
```

---

## Storage

**Location:** `~/Library/Application Support/Aurelia/`

```
├── clipboard.db              # SQLite database
└── images/
    └── <uuid>.png            # Image files
```

### Database Schema

```sql
-- Clipboard items
CREATE TABLE clipboard_items (
    id TEXT PRIMARY KEY,
    content_type TEXT NOT NULL,     -- "text", "image", "file"
    text_content TEXT,
    image_filename TEXT,
    file_paths TEXT,
    timestamp REAL NOT NULL,
    program_name TEXT NOT NULL,
    is_pinned INTEGER DEFAULT 0
);

-- Ignored applications
CREATE TABLE ignored_apps (
    bundle_id TEXT PRIMARY KEY,
    app_name TEXT NOT NULL,
    added_at REAL NOT NULL
);
```

---

## Architecture

### Data Flow

```
App Launch → Load Settings → Load from DB → Start Timer → Setup Menu Bar
    ↓
Every 0.5s: Check NSPasteboard.changeCount
    ↓
Check privacy rules (paused? ignored app?)
    ↓
Read content (files → text → images) + source app
    ↓
Deduplicate → Insert to DB → Update UI → Prune expired
```

### Key Components

| Component | Responsibility |
|-----------|---------------|
| `ClipboardManager` | Monitors clipboard (singleton), manages items, filtering |
| `StorageManager` | SQLite CRUD, image file management, migrations |
| `PrivacyManager` | Ignored apps, pause toggle |
| `MenuBarManager` | Status item, popover display |
| `AppSettings` | Retention period, launch at login |
| `HotkeyManager` | Global keyboard shortcut |

---

## UI Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                              Aurelia                        [⚙️] │
├──────────────┬──────────────────────────────────────────────────┤
│              │  [🔍 Search...]           [All][Text][Links]...  │
│  All Items   │──────────────────────────────────────────────────│
│  ★ Starred   │                                                  │
│              │   ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐            │
│              │   │Card │  │Card │  │Card │  │Card │  ───▶      │
│              │   │     │  │     │  │     │  │     │            │
│              │   └─────┘  └─────┘  └─────┘  └─────┘            │
│              │                                                  │
└──────────────┴──────────────────────────────────────────────────┘
```

---

## Settings

### General Tab
- **Keyboard Shortcut**: Configurable hotkey to show Aurelia (default: Cmd+Shift+V)
- **History Retention**: 1 Day → 1 Month → Forever (slider)
- **Launch at Login**: Toggle to start app on login
- Starred items are never deleted

### Privacy Tab
- **Pause Monitoring**: Toggle to temporarily stop capturing
- **Ignored Apps**: List of apps whose clipboard content is not captured
- **Add Password Managers**: One-click to add 1Password, LastPass, Keychain, Bitwarden, etc.

---

## Context Menu Actions

Right-click on any clipboard item:
- **Copy** - Copy to clipboard
- **Copy as Plain Text** - Strip formatting (text only)
- **Star / Unstar** - Toggle pinned status
- **Delete** - Remove item

---

## Menu Bar

Click the menu bar icon for:
- Recent 15 items (compact list)
- Click to copy
- Open App button
- Preferences
- Quit

---

## Frameworks

- **SwiftUI** - UI framework
- **AppKit** - NSPasteboard, NSWorkspace, NSStatusItem
- **SQLite3** - Database (built-in)

No third-party dependencies.

---

## Migration

On first launch:
1. Migrates data from old `ClipboardApp` directory to `Aurelia`
2. Migrates legacy JSON storage to SQLite
3. Runs schema migrations for new columns/tables
