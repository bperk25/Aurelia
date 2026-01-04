//
//  MenuBarManager.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import AppKit
import SwiftUI

@Observable
final class MenuBarManager {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    private init() {}

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(
            width: AureliaDesign.Layout.menuBarPopoverWidth,
            height: AureliaDesign.Layout.menuBarPopoverHeight
        )
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView()
        )
    }

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func showPopover() {
        guard let button = statusItem?.button else { return }
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func hidePopover() {
        popover?.performClose(nil)
    }
}
