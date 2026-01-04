//
//  AppDelegate.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var mainWindowDelegate: MainWindowDelegate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBarManager.shared.setup()
        FloatingPanelManager.shared.setup()
        ClipboardManager.shared.startMonitoring()
        HotkeyManager.shared.startMonitoring()

        // Start as menu bar only app (hide dock icon, hide main window)
        NSApp.setActivationPolicy(.accessory)

        // Close any open windows on launch and set up window delegate
        DispatchQueue.main.async { [weak self] in
            for window in NSApp.windows {
                if window.title == "Aurelia" || window.identifier?.rawValue.contains("ContentView") == true {
                    // Set up delegate to intercept close
                    self?.setupWindowDelegate(for: window)
                    window.close()
                }
            }
        }

        // Watch for new windows to set up delegate
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    @objc func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.title == "Aurelia",
              window.delegate == nil || !(window.delegate is MainWindowDelegate) else {
            return
        }
        setupWindowDelegate(for: window)
    }

    private func setupWindowDelegate(for window: NSWindow) {
        let delegate = MainWindowDelegate()
        mainWindowDelegate = delegate
        window.delegate = delegate
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running in menu bar when window is closed
        false
    }

    /// Show the main window and dock icon
    static func showMainWindow() {
        // Show dock icon
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Find or create the main window
        if let window = NSApp.windows.first(where: { $0.title == "Aurelia" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // If no window exists, create one
            let contentView = ContentView()
                .frame(
                    minWidth: AureliaDesign.Layout.minWindowWidth,
                    minHeight: AureliaDesign.Layout.minWindowHeight
                )
                .preferredColorScheme(.dark)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: AureliaDesign.Layout.minWindowWidth, height: AureliaDesign.Layout.minWindowHeight),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Aurelia"
            window.contentView = NSHostingView(rootView: contentView)
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// Hide dock icon (called when main window closes)
    static func hideDockIcon() {
        // Only hide if no windows are visible
        let hasVisibleWindows = NSApp.windows.contains { window in
            window.isVisible && window.title == "Aurelia"
        }

        if !hasVisibleWindows {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - Main Window Delegate

/// Intercepts window close to hide instead of close, keeping app running
class MainWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide the window instead of closing
        sender.orderOut(nil)

        // Hide dock icon since window is hidden
        DispatchQueue.main.async {
            AppDelegate.hideDockIcon()
        }

        // Return false to prevent actual close (which could terminate app)
        return false
    }

    func windowWillClose(_ notification: Notification) {
        // Backup: ensure dock icon is hidden
        DispatchQueue.main.async {
            AppDelegate.hideDockIcon()
        }
    }
}
