# Aurelia

A clipboard manager for macOS.

Aurelia captures your clipboard history - text, images, links, and files - so you never lose what you've copied. It lives in your menu bar, ready when you need it.

**Requires macOS 15.2+ (Sequoia)**

---

## Features

### Clipboard History
- Automatically captures text, images, links, and files
- Deduplicates items (re-copying moves to front)
- Tracks source app and timestamp
- Auto-categorizes by content type

### Quick Access
- Global hotkey to open floating panel (default: `Ctrl+Shift+V`)
- Menu bar icon with popover
- Keyboard navigation (arrows to browse, Enter to paste, Escape to close)

### Organization
- Pin items to keep them permanently
- Create custom groups for organizing items
- Full-text search
- Filter by content type (Text, Links, Images, Files)

### Paste Queue
- Queue multiple items and paste them in sequence
- Drag to reorder
- Flip order, reset, or clear the queue

### Privacy
- Pause clipboard monitoring
- Auto-ignores password managers (1Password, LastPass, Bitwarden, etc.)
- Add any app to the ignore list

### Previews
- Image thumbnails
- OpenGraph previews for links
- File name lists

### Settings
- Configurable retention (1 day to forever)
- Custom hotkeys
- List or thumbnail view modes
- Launch at login

---

## Keyboard Shortcuts

| Action | Default |
|--------|---------|
| Open Panel | `Ctrl + Shift + V` |
| Toggle Paste Queue | `Cmd + Shift + C` |
| Navigate | `↑` `↓` |
| Select/Paste | `Enter` |
| Close | `Escape` |

---

## Building

```bash
# Open in Xcode
open Aurelia.xcodeproj

# Build from command line
xcodebuild -project Aurelia.xcodeproj -scheme Aurelia build

# Run tests
xcodebuild test -project Aurelia.xcodeproj -scheme Aurelia
```

---

## Requirements

- macOS 15.2+ (Sequoia)
- No external dependencies

---

## Data Storage

Clipboard history is stored locally at `~/Library/Application Support/Aurelia/`

---

## License

MIT
