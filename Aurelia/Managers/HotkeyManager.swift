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
    private let keyCodeKey = "hotkeyKeyCode"
    private let modifiersKey = "hotkeyModifiers"

    private var globalMonitor: Any?
    private var localMonitor: Any?

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

    private init() {
        let savedKeyCode = defaults.integer(forKey: keyCodeKey)
        let savedModifiers = defaults.integer(forKey: modifiersKey)

        if savedKeyCode == 0 && savedModifiers == 0 {
            // Default: Option+Shift+J
            self.keyCode = UInt16(kVK_ANSI_J)
            self.modifiers = [.option, .shift]
        } else {
            self.keyCode = UInt16(savedKeyCode)
            self.modifiers = NSEvent.ModifierFlags(rawValue: UInt(savedModifiers))
        }
    }

    func startMonitoring() {
        guard isEnabled else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }

    func stopMonitoring() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let eventModifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])

        guard event.keyCode == keyCode && eventModifiers == modifiers else {
            return false
        }

        toggleMenuBarPopover()
        return true
    }

    private func toggleMenuBarPopover() {
        NSApp.activate(ignoringOtherApps: true)
        MenuBarManager.shared.togglePopover()
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
        stopMonitoring()
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
