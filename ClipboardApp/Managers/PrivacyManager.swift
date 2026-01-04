//
//  PrivacyManager.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import Foundation
import AppKit

struct IgnoredApp: Identifiable, Equatable {
    let bundleID: String
    let appName: String
    let addedAt: Date

    var id: String { bundleID }
}

@Observable
final class PrivacyManager {
    static let shared = PrivacyManager()

    private(set) var ignoredApps: [IgnoredApp] = []
    var isMonitoringPaused: Bool {
        didSet {
            UserDefaults.standard.set(isMonitoringPaused, forKey: "isMonitoringPaused")
        }
    }

    private let storage = StorageManager.shared

    // Default password managers to ignore
    static let defaultIgnoredApps: [(bundleID: String, name: String)] = [
        ("com.agilebits.onepassword7", "1Password 7"),
        ("com.1password.1password", "1Password"),
        ("com.lastpass.LastPass", "LastPass"),
        ("com.apple.keychainaccess", "Keychain Access"),
        ("com.bitwarden.desktop", "Bitwarden"),
        ("com.dashlane.Dashlane", "Dashlane"),
        ("com.keepersecurity.keeper", "Keeper"),
        ("org.nickvision.keyring", "Keyring"),
    ]

    private init() {
        isMonitoringPaused = UserDefaults.standard.bool(forKey: "isMonitoringPaused")
        loadIgnoredApps()
    }

    func isAppIgnored(bundleID: String?) -> Bool {
        guard let bundleID = bundleID else { return false }
        return ignoredApps.contains { $0.bundleID == bundleID }
    }

    func addIgnoredApp(bundleID: String, appName: String) {
        guard !isAppIgnored(bundleID: bundleID) else { return }

        let app = IgnoredApp(bundleID: bundleID, appName: appName, addedAt: Date())
        storage.insertIgnoredApp(app)
        ignoredApps.append(app)
    }

    func removeIgnoredApp(bundleID: String) {
        storage.deleteIgnoredApp(bundleID: bundleID)
        ignoredApps.removeAll { $0.bundleID == bundleID }
    }

    func addDefaultPasswordManagers() {
        for app in Self.defaultIgnoredApps {
            addIgnoredApp(bundleID: app.bundleID, appName: app.name)
        }
    }

    private func loadIgnoredApps() {
        ignoredApps = storage.fetchIgnoredApps()
    }

    // MARK: - Running Apps

    func getRunningApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
}
