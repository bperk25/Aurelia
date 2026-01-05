//
//  GeneralSettingsView.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import SwiftUI
import Carbon.HIToolbox

struct GeneralSettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var hotkeyManager = HotkeyManager.shared
    @State private var queueManager = PasteQueueManager.shared
    @State private var sliderIndex: Double
    @State private var isRecordingShortcut = false
    @State private var isRecordingQueueShortcut = false

    private let retentionOptions = RetentionPeriod.sliderCases

    init() {
        let currentIndex = RetentionPeriod.sliderCases.firstIndex(of: AppSettings.shared.retentionPeriod) ?? 2
        _sliderIndex = State(initialValue: Double(currentIndex))
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: AureliaDesign.Spacing.sm) {
                    HStack {
                        Text("Show Aurelia")

                        Spacer()

                        ShortcutRecorderButton(
                            isRecording: $isRecordingShortcut,
                            hotkeyManager: hotkeyManager
                        )
                    }

                    if isRecordingShortcut {
                        Text("Press a combination like ⌘V or ⌃⇧V")
                            .font(AureliaDesign.Typography.caption)
                            .foregroundStyle(AureliaColors.electricCyan)
                    }
                }
            } header: {
                Text("Keyboard Shortcut")
            } footer: {
                Text("Use 1-2 modifiers (Ctrl, Shift, Cmd, Option) + a letter or number key.")
                    .font(AureliaDesign.Typography.caption)
                    .foregroundStyle(AureliaColors.secondaryText)
            }

            Section {
                Picker("Panel View", selection: Binding(
                    get: { settings.panelViewMode },
                    set: { settings.panelViewMode = $0 }
                )) {
                    ForEach(PanelViewMode.allCases, id: \.self) { mode in
                        Label(mode.displayName, systemImage: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Quick Panel Appearance")
            } footer: {
                Text("Choose how clipboard items appear in the quick panel (triggered by shortcut).")
                    .font(AureliaDesign.Typography.caption)
                    .foregroundStyle(AureliaColors.secondaryText)
            }

            // MARK: - Paste Queue Settings
            Section {
                VStack(alignment: .leading, spacing: AureliaDesign.Spacing.sm) {
                    HStack {
                        Text("Queue Mode")

                        Spacer()

                        QueueShortcutRecorderButton(
                            isRecording: $isRecordingQueueShortcut,
                            hotkeyManager: hotkeyManager
                        )
                    }

                    if isRecordingQueueShortcut {
                        Text("Press a combination like ⌘⇧C")
                            .font(AureliaDesign.Typography.caption)
                            .foregroundStyle(AureliaColors.electricCyan)
                    }
                }

                Toggle("Auto-clear queue after complete", isOn: Binding(
                    get: { queueManager.autoClearAfterComplete },
                    set: { queueManager.autoClearAfterComplete = $0 }
                ))

                Toggle("Keep pasted items visible", isOn: Binding(
                    get: { queueManager.keepPastedItemsVisible },
                    set: { queueManager.keepPastedItemsVisible = $0 }
                ))
            } header: {
                HStack {
                    Image(systemName: "list.number")
                        .foregroundStyle(AureliaColors.electricCyan)
                    Text("Paste Queue")
                }
            } footer: {
                Text("Queue Mode lets you copy multiple items, then paste them in sequence. Press the shortcut to toggle.")
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
                Text("Items older than this will dissolve into the deep. Anchored items are preserved forever.")
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

    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: AureliaDesign.Spacing.sm) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: AureliaDesign.Spacing.xs) {
                    if isRecording {
                        Image(systemName: "keyboard")
                            .foregroundStyle(AureliaColors.electricCyan)
                        Text("Type shortcut...")
                    } else {
                        Text(hotkeyManager.shortcutDisplayString)
                    }
                }
                .font(AureliaDesign.Typography.body)
                .foregroundStyle(isRecording ? AureliaColors.electricCyan : AureliaColors.primaryText)
                .padding(.horizontal, AureliaDesign.Spacing.md)
                .padding(.vertical, AureliaDesign.Spacing.sm)
                .frame(minWidth: 120)
                .background(
                    RoundedRectangle(cornerRadius: AureliaDesign.Radius.md)
                        .fill(isRecording ? AureliaColors.electricCyan.opacity(0.15) : AureliaColors.abyssMedium)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AureliaDesign.Radius.md)
                        .stroke(isRecording ? AureliaColors.electricCyan : AureliaColors.border, lineWidth: isRecording ? 2 : 1)
                )
            }
            .buttonStyle(.plain)

            if hotkeyManager.isEnabled && !isRecording {
                Button {
                    hotkeyManager.clearShortcut()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AureliaColors.tertiaryText)
                }
                .buttonStyle(.plain)
                .help("Clear shortcut")
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true

        // Stop the hotkey manager's monitoring while recording
        hotkeyManager.stopMonitoring()

        // Add local event monitor to capture key presses
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
            return nil // Consume the event
        }
    }

    private func stopRecording() {
        isRecording = false

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        // Restart hotkey monitoring
        hotkeyManager.startMonitoring()
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Check for Escape to cancel
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])

        // Count modifiers - require at least 1
        var modifierCount = 0
        if modifiers.contains(.command) { modifierCount += 1 }
        if modifiers.contains(.option) { modifierCount += 1 }
        if modifiers.contains(.shift) { modifierCount += 1 }
        if modifiers.contains(.control) { modifierCount += 1 }

        guard modifierCount >= 1 else {
            // Need at least one modifier, keep recording
            return
        }

        // Check if it's a valid letter/number key (not just modifier keys)
        let keyCode = event.keyCode
        guard isValidKeyCode(keyCode) else {
            return
        }

        // Valid shortcut! Save it
        hotkeyManager.setShortcut(keyCode: keyCode, modifiers: modifiers)
        stopRecording()
    }

    private func isValidKeyCode(_ keyCode: UInt16) -> Bool {
        // Letter keys A-Z
        let letterKeys: [Int] = [
            kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E,
            kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J,
            kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O,
            kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R, kVK_ANSI_S, kVK_ANSI_T,
            kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X, kVK_ANSI_Y,
            kVK_ANSI_Z
        ]

        // Number keys 0-9
        let numberKeys: [Int] = [
            kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
            kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9
        ]

        let validKeys = letterKeys + numberKeys
        return validKeys.contains(Int(keyCode))
    }
}

// MARK: - Queue Shortcut Recorder Button

struct QueueShortcutRecorderButton: View {
    @Binding var isRecording: Bool
    var hotkeyManager: HotkeyManager

    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: AureliaDesign.Spacing.sm) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack(spacing: AureliaDesign.Spacing.xs) {
                    if isRecording {
                        Image(systemName: "keyboard")
                            .foregroundStyle(AureliaColors.electricCyan)
                        Text("Type shortcut...")
                    } else {
                        Text(hotkeyManager.queueShortcutDisplayString)
                    }
                }
                .font(AureliaDesign.Typography.body)
                .foregroundStyle(isRecording ? AureliaColors.electricCyan : AureliaColors.primaryText)
                .padding(.horizontal, AureliaDesign.Spacing.md)
                .padding(.vertical, AureliaDesign.Spacing.sm)
                .frame(minWidth: 120)
                .background(
                    RoundedRectangle(cornerRadius: AureliaDesign.Radius.md)
                        .fill(isRecording ? AureliaColors.electricCyan.opacity(0.15) : AureliaColors.abyssMedium)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AureliaDesign.Radius.md)
                        .stroke(isRecording ? AureliaColors.electricCyan : AureliaColors.border, lineWidth: isRecording ? 2 : 1)
                )
            }
            .buttonStyle(.plain)

            if hotkeyManager.isQueueEnabled && !isRecording {
                Button {
                    hotkeyManager.clearQueueShortcut()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AureliaColors.tertiaryText)
                }
                .buttonStyle(.plain)
                .help("Clear shortcut")
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true

        // Stop the hotkey manager's monitoring while recording
        hotkeyManager.stopMonitoring()

        // Add local event monitor to capture key presses
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
            return nil // Consume the event
        }
    }

    private func stopRecording() {
        isRecording = false

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        // Restart hotkey monitoring
        hotkeyManager.startMonitoring()
    }

    private func handleKeyEvent(_ event: NSEvent) {
        // Check for Escape to cancel
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }

        let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])

        // Count modifiers - require at least 1
        var modifierCount = 0
        if modifiers.contains(.command) { modifierCount += 1 }
        if modifiers.contains(.option) { modifierCount += 1 }
        if modifiers.contains(.shift) { modifierCount += 1 }
        if modifiers.contains(.control) { modifierCount += 1 }

        guard modifierCount >= 1 else {
            // Need at least one modifier, keep recording
            return
        }

        // Check if it's a valid letter/number key (not just modifier keys)
        let keyCode = event.keyCode
        guard isValidKeyCode(keyCode) else {
            return
        }

        // Valid shortcut! Save it
        hotkeyManager.setQueueShortcut(keyCode: keyCode, modifiers: modifiers)
        stopRecording()
    }

    private func isValidKeyCode(_ keyCode: UInt16) -> Bool {
        // Letter keys A-Z
        let letterKeys: [Int] = [
            kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E,
            kVK_ANSI_F, kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J,
            kVK_ANSI_K, kVK_ANSI_L, kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O,
            kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R, kVK_ANSI_S, kVK_ANSI_T,
            kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X, kVK_ANSI_Y,
            kVK_ANSI_Z
        ]

        // Number keys 0-9
        let numberKeys: [Int] = [
            kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
            kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9
        ]

        let validKeys = letterKeys + numberKeys
        return validKeys.contains(Int(keyCode))
    }
}

#Preview {
    GeneralSettingsView()
}
