//
//  GeneralSettingsView.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import SwiftUI

struct GeneralSettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var hotkeyManager = HotkeyManager.shared
    @State private var sliderIndex: Double
    @State private var isRecordingShortcut = false

    private let retentionOptions = RetentionPeriod.sliderCases

    init() {
        let currentIndex = RetentionPeriod.sliderCases.firstIndex(of: AppSettings.shared.retentionPeriod) ?? 2
        _sliderIndex = State(initialValue: Double(currentIndex))
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Show Aurelia")

                    Spacer()

                    ShortcutRecorderButton(
                        isRecording: $isRecordingShortcut,
                        hotkeyManager: hotkeyManager
                    )
                }
            } header: {
                Text("Keyboard Shortcut")
            } footer: {
                Text("Press the shortcut anywhere to show Aurelia.")
                    .font(AureliaDesign.Typography.caption)
                    .foregroundStyle(AureliaColors.secondaryText)
            }

            Section {
                VStack(alignment: .leading, spacing: AureliaDesign.Spacing.md) {
                    Text("Keep clipboard items for:")
                        .font(AureliaDesign.Typography.body)

                    HStack {
                        Text("1 Day")
                            .font(AureliaDesign.Typography.caption)
                            .foregroundStyle(AureliaColors.secondaryText)

                        Slider(
                            value: $sliderIndex,
                            in: 0...Double(retentionOptions.count - 1),
                            step: 1
                        )
                        .onChange(of: sliderIndex) { _, newValue in
                            let index = Int(newValue)
                            if index < retentionOptions.count {
                                settings.retentionPeriod = retentionOptions[index]
                            }
                        }

                        Text("Forever")
                            .font(AureliaDesign.Typography.caption)
                            .foregroundStyle(AureliaColors.secondaryText)
                    }

                    Text(settings.retentionPeriod.displayName)
                        .font(AureliaDesign.Typography.title)
                        .foregroundStyle(AureliaColors.accent)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } header: {
                Text("History Retention")
            } footer: {
                Text("Items older than this will be automatically deleted. Starred items are never deleted.")
                    .font(AureliaDesign.Typography.caption)
                    .foregroundStyle(AureliaColors.secondaryText)
            }

            Section {
                Toggle("Launch Aurelia at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                ))
            } header: {
                Text("Startup")
            } footer: {
                Text("Aurelia will start automatically when you log in.")
                    .font(AureliaDesign.Typography.caption)
                    .foregroundStyle(AureliaColors.secondaryText)
            }

            Section {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(AureliaColors.secondaryText)
                }

                LabeledContent("Build") {
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundStyle(AureliaColors.secondaryText)
                }
            } header: {
                Text("About Aurelia")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcut Recorder Button

struct ShortcutRecorderButton: View {
    @Binding var isRecording: Bool
    var hotkeyManager: HotkeyManager

    var body: some View {
        HStack(spacing: AureliaDesign.Spacing.sm) {
            Button {
                isRecording.toggle()
            } label: {
                Text(isRecording ? "Press shortcut..." : hotkeyManager.shortcutDisplayString)
                    .font(AureliaDesign.Typography.body)
                    .foregroundStyle(isRecording ? AureliaColors.accent : AureliaColors.primaryText)
                    .padding(.horizontal, AureliaDesign.Spacing.md)
                    .padding(.vertical, AureliaDesign.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: AureliaDesign.Radius.sm)
                            .fill(isRecording ? AureliaColors.accent.opacity(0.1) : AureliaColors.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AureliaDesign.Radius.sm)
                            .stroke(isRecording ? AureliaColors.accent : AureliaColors.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .onKeyPress { keyPress in
                guard isRecording else { return .ignored }

                let modifiers = keyPress.modifiers
                guard modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option) else {
                    return .ignored
                }

                // Convert KeyEquivalent to keyCode
                if let keyCode = keyEquivalentToKeyCode(keyPress.key) {
                    var nsModifiers: NSEvent.ModifierFlags = []
                    if modifiers.contains(.command) { nsModifiers.insert(.command) }
                    if modifiers.contains(.shift) { nsModifiers.insert(.shift) }
                    if modifiers.contains(.option) { nsModifiers.insert(.option) }
                    if modifiers.contains(.control) { nsModifiers.insert(.control) }

                    hotkeyManager.setShortcut(keyCode: keyCode, modifiers: nsModifiers)
                    isRecording = false
                    return .handled
                }
                return .ignored
            }

            if hotkeyManager.isEnabled {
                Button {
                    hotkeyManager.clearShortcut()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AureliaColors.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func keyEquivalentToKeyCode(_ key: KeyEquivalent) -> UInt16? {
        let char = key.character
        switch char {
        case "a": return 0x00
        case "b": return 0x0B
        case "c": return 0x08
        case "d": return 0x02
        case "e": return 0x0E
        case "f": return 0x03
        case "g": return 0x05
        case "h": return 0x04
        case "i": return 0x22
        case "j": return 0x26
        case "k": return 0x28
        case "l": return 0x25
        case "m": return 0x2E
        case "n": return 0x2D
        case "o": return 0x1F
        case "p": return 0x23
        case "q": return 0x0C
        case "r": return 0x0F
        case "s": return 0x01
        case "t": return 0x11
        case "u": return 0x20
        case "v": return 0x09
        case "w": return 0x0D
        case "x": return 0x07
        case "y": return 0x10
        case "z": return 0x06
        case "0": return 0x1D
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "5": return 0x17
        case "6": return 0x16
        case "7": return 0x1A
        case "8": return 0x1C
        case "9": return 0x19
        default: return nil
        }
    }
}

#Preview {
    GeneralSettingsView()
}
