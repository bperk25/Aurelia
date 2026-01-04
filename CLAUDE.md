# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Aurelia is a macOS clipboard manager built with SwiftUI for macOS 15.2+ (Sequoia). It captures clipboard history (text, images, files), provides search/filtering, privacy controls, and menu bar integration. No external dependencies - uses only built-in Apple frameworks.

## Build Commands

```bash
# Open in Xcode
open Aurelia.xcodeproj

# Build from command line
xcodebuild -project Aurelia.xcodeproj -scheme Aurelia build

# Run tests
xcodebuild test -project Aurelia.xcodeproj -scheme Aurelia

# Build release
xcodebuild -project Aurelia.xcodeproj -scheme Aurelia -configuration Release build
```

## Architecture

### Core Managers (Singleton Pattern)

- **ClipboardManager** - Singleton that monitors NSPasteboard every 0.5s, manages item lifecycle, filtering, and search
- **StorageManager** - SQLite3 database at `~/Library/Application Support/Aurelia/clipboard.db` with image file storage
- **PrivacyManager** - Maintains app ignore list (password managers pre-configured), pause monitoring toggle
- **MenuBarManager** - NSStatusItem with NSPopover for quick access
- **HotkeyManager** - Configurable global keyboard shortcut (default: Cmd+Shift+V)

### Data Flow

```
Timer (0.5s) → Check NSPasteboard.changeCount → Check Privacy Rules
→ Read Content (files → text → images priority) → Get Source App
→ Deduplicate → Insert to SQLite → Update UI → Prune Expired Items
```

### Key Files

| File | Purpose |
|------|---------|
| `ClipboardManager.swift` | Core monitoring logic, filtering |
| `StorageManager.swift` | SQLite CRUD, migrations, image storage |
| `ContentView.swift` | Main window with NavigationSplitView |
| `Models.swift` | ClipboardItem, ClipboardContent, ContentTypeFilter |
| `Theme/DesignSystem.swift` | Design tokens - use `AureliaDesign` for spacing, typography |

### Database Schema

Two main tables: `clipboard_items` (content, timestamp, program_name, is_pinned) and `ignored_apps` (bundle_id, app_name). Storage location: `~/Library/Application Support/Aurelia/`

## Code Conventions

- Use `@Observable` classes for reactive state (not Combine)
- Follow existing `AureliaDesign` tokens for UI consistency (spacing, typography, colors)
- All persistence goes through `StorageManager`
- Check `PrivacyManager` rules before capturing clipboard content
- Tests use Swift Testing framework (not XCTest)

## Frameworks Used

- **SwiftUI** - UI
- **AppKit** - NSPasteboard, NSWorkspace, NSStatusItem, NSImage
- **SQLite3** - Built-in database (no ORM)
