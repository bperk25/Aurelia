//
//  HotkeyManager.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import AppKit
import Carbon.HIToolbox

@Observable
final class HotkeyManager {
    static let shared = HotkeyManager()

    private let defaults = UserDefaults.standard

    // Panel shortcut keys
    private let keyCodeKey = "hotkeyKeyCode"
    private let modifiersKey = "hotkeyModifiers"

    // Queue shortcut keys
    private let queueKeyCodeKey = "queueHotkeyKeyCode"
    private let queueModifiersKey = "queueHotkeyModifiers"

    private var hotKeyRef: EventHotKeyRef?
    private var queueHotKeyRef: EventHotKeyRef?

    private static let hotKeyID = EventHotKeyID(signature: OSType(0x4155524C), id: 1) // "AURL" - Panel
    private static let queueHotKeyID = EventHotKeyID(signature: OSType(0x4155524C), id: 2) // "AURL" - Queue

    // MARK: - Panel Shortcut

    var keyCode: UInt16 {
        didSet {
            defaults.set(Int(keyCode), forKey: keyCodeKey)
            restartMonitoring()
        }
    }

    var modifiers: NSEvent.ModifierFlags {
        didSet {
            defaults.set(modifiers.rawValue, forKey: modifiersKey)
            restartMonitoring()
        }
    }

    var isEnabled: Bool {
        keyCode != 0
    }

    var shortcutDisplayString: String {
        guard isEnabled else { return "Not Set" }
        return formatShortcut(keyCode: keyCode, modifiers: modifiers)
    }

    // MARK: - Queue Shortcut

    var queueKeyCode: UInt16 {
        didSet {
            defaults.set(Int(queueKeyCode), forKey: queueKeyCodeKey)
            restartQueueMonitoring()
        }
    }

    var queueModifiers: NSEvent.ModifierFlags {
        didSet {
            defaults.set(queueModifiers.rawValue, forKey: queueModifiersKey)
            restartQueueMonitoring()
        }
    }

    var isQueueEnabled: Bool {
        queueKeyCode != 0
    }

    var queueShortcutDisplayString: String {
        guard isQueueEnabled else { return "Not Set" }
        return formatShortcut(keyCode: queueKeyCode, modifiers: queueModifiers)
    }

    // MARK: - Initialization

    private init() {
        // Load panel shortcut
        let savedKeyCode = defaults.integer(forKey: keyCodeKey)
        let savedModifiers = defaults.integer(forKey: modifiersKey)

        if savedKeyCode == 0 && savedModifiers == 0 {
            // Default: Ctrl+Shift+V
            self.keyCode = UInt16(kVK_ANSI_V)
            self.modifiers = [.control, .shift]
        } else {
            self.keyCode = UInt16(savedKeyCode)
            self.modifiers = NSEvent.ModifierFlags(rawValue: UInt(savedModifiers))
        }

        // Load queue shortcut
        let savedQueueKeyCode = defaults.integer(forKey: queueKeyCodeKey)
        let savedQueueModifiers = defaults.integer(forKey: queueModifiersKey)

        if savedQueueKeyCode == 0 && savedQueueModifiers == 0 {
            // Default: Cmd+Shift+C
            self.queueKeyCode = UInt16(kVK_ANSI_C)
            self.queueModifiers = [.command, .shift]
        } else {
            self.queueKeyCode = UInt16(savedQueueKeyCode)
            self.queueModifiers = NSEvent.ModifierFlags(rawValue: UInt(savedQueueModifiers))
        }

        // Install the global event handler
        installEventHandler()
    }

    private func formatShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []

        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        if let keyString = keyCodeToString(keyCode) {
            parts.append(keyString)
        }

        return parts.joined()
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if hotKeyID.signature == HotkeyManager.hotKeyID.signature {
                    DispatchQueue.main.async {
                        if hotKeyID.id == HotkeyManager.hotKeyID.id {
                            // Panel shortcut
                            HotkeyManager.shared.toggleMenuBarPopover()
                        } else if hotKeyID.id == HotkeyManager.queueHotKeyID.id {
                            // Queue shortcut
                            HotkeyManager.shared.toggleQueueMode()
                        }
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }

    private func toggleQueueMode() {
        if !PasteQueueManager.shared.isQueueModeActive {
            // Activate queue mode FIRST, then copy selected text
            // This way the copied text will be captured into the queue
            PasteQueueManager.shared.activate()
            // Small delay to ensure queue mode is active before copy
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.simulateCopy()
            }
        } else {
            PasteQueueManager.shared.deactivate()
        }
    }

    /// Simulate Cmd+C to copy selected text
    private func simulateCopy() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down for Cmd+C
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        keyDown?.flags = .maskCommand

        // Key up for Cmd+C
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        keyUp?.flags = .maskCommand

        // Post the events
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Panel Hotkey Registration

    func startMonitoring() {
        startPanelMonitoring()
        startQueueMonitoring()
    }

    func stopMonitoring() {
        stopPanelMonitoring()
        stopQueueMonitoring()
    }

    private func startPanelMonitoring() {
        guard isEnabled else { return }
        guard hotKeyRef == nil else { return } // Already registered

        let carbonModifiers = carbonModifierFlags(from: modifiers)

        let hotKeyID = HotkeyManager.hotKeyID
        var ref: EventHotKeyRef?

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr {
            hotKeyRef = ref
        } else {
            print("Failed to register panel hotkey: \(status)")
        }
    }

    private func stopPanelMonitoring() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func restartMonitoring() {
        stopPanelMonitoring()
        startPanelMonitoring()
    }

    // MARK: - Queue Hotkey Registration

    private func startQueueMonitoring() {
        guard isQueueEnabled else { return }
        guard queueHotKeyRef == nil else { return } // Already registered

        let carbonModifiers = carbonModifierFlags(from: queueModifiers)

        let hotKeyID = HotkeyManager.queueHotKeyID
        var ref: EventHotKeyRef?

        let status = RegisterEventHotKey(
            UInt32(queueKeyCode),
            carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr {
            queueHotKeyRef = ref
        } else {
            print("Failed to register queue hotkey: \(status)")
        }
    }

    private func stopQueueMonitoring() {
        if let ref = queueHotKeyRef {
            UnregisterEventHotKey(ref)
            queueHotKeyRef = nil
        }
    }

    private func restartQueueMonitoring() {
        stopQueueMonitoring()
        startQueueMonitoring()
    }

    private func toggleMenuBarPopover() {
        // Use floating panel instead of menu bar popover for better focus handling
        FloatingPanelManager.shared.toggle()
    }

    func setShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    func clearShortcut() {
        self.keyCode = 0
        self.modifiers = []
        defaults.removeObject(forKey: keyCodeKey)
        defaults.removeObject(forKey: modifiersKey)
        stopPanelMonitoring()
    }

    func setQueueShortcut(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.queueKeyCode = keyCode
        self.queueModifiers = modifiers
    }

    func clearQueueShortcut() {
        self.queueKeyCode = 0
        self.queueModifiers = []
        defaults.removeObject(forKey: queueKeyCodeKey)
        defaults.removeObject(forKey: queueModifiersKey)
        stopQueueMonitoring()
    }

    /// Convert NSEvent modifier flags to Carbon modifier flags
    private func carbonModifierFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonFlags: UInt32 = 0

        if flags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if flags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }

        return carbonFlags
    }

    /// Simulate Cmd+V to paste clipboard content into the active app
    static func simulatePaste() {
        // Small delay to ensure clipboard is updated and popover is closed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let source = CGEventSource(stateID: .hidSystemState)

            // Key down for Cmd+V
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
            keyDown?.flags = .maskCommand

            // Key up for Cmd+V
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
            keyUp?.flags = .maskCommand

            // Post the events
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
        }
    }

    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: return nil
        }
    }
}
