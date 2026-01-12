//
//  MenuBarManager.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import AppKit
import SwiftUI

// MARK: - Notification Names

extension Notification.Name {
    static let clipboardDidChange = Notification.Name("clipboardDidChange")
}

@Observable
final class MenuBarManager {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    /// The app that was active before showing the popover (so we can return to it)
    var previousApp: NSRunningApplication?

    private init() {}

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            if let image = NSImage(named: "MenuBarIcon") {
                // Set proper size for menu bar (18x18 points for proper alignment)
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            }
            button.action = #selector(togglePopover)
            button.target = self

            // Enable layer-backed view for animations
            button.wantsLayer = true
            button.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(
            width: AureliaDesign.Layout.menuBarPopoverWidth,
            height: AureliaDesign.Layout.menuBarPopoverHeight
        )
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView()
                .preferredColorScheme(.dark)
        )

        // Observe clipboard changes for pulse animation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipboardDidChange),
            name: .clipboardDidChange,
            object: nil
        )
    }

    @objc private func clipboardDidChange() {
        pulseIcon()
    }

    /// Pulse the menu bar icon (contract then expand) - jellyfish propulsion effect
    func pulseIcon() {
        guard let button = statusItem?.button, let layer = button.layer else { return }

        // Ensure we're on main thread
        DispatchQueue.main.async {
            // Create pulse animation
            let pulseAnimation = CAKeyframeAnimation(keyPath: "transform.scale")
            pulseAnimation.values = [1.0, 0.8, 1.1, 1.0]
            pulseAnimation.keyTimes = [0, 0.3, 0.6, 1.0]
            pulseAnimation.duration = 0.4
            pulseAnimation.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeOut)
            ]

            // Create subtle glow effect via opacity
            let glowAnimation = CAKeyframeAnimation(keyPath: "opacity")
            glowAnimation.values = [1.0, 0.6, 1.0, 1.0]
            glowAnimation.keyTimes = [0, 0.3, 0.6, 1.0]
            glowAnimation.duration = 0.4

            // Group animations
            let group = CAAnimationGroup()
            group.animations = [pulseAnimation, glowAnimation]
            group.duration = 0.4

            layer.add(group, forKey: "pulseAnimation")
        }
    }

    @objc func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Remember which app was active before showing popover
            previousApp = NSWorkspace.shared.frontmostApplication

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Make popover the key window without activating the full app
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func showPopover() {
        guard let button = statusItem?.button else { return }
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func hidePopover() {
        popover?.performClose(nil)
    }

    /// Return focus to the previous app (used before pasting)
    func activatePreviousApp() {
        previousApp?.activate(options: [])
    }
}
