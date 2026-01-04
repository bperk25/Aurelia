//
//  PrivacySettingsView.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import SwiftUI
import AppKit

struct PrivacySettingsView: View {
    @State private var privacy = PrivacyManager.shared
    @State private var showingAppPicker = false

    var body: some View {
        Form {
            // Pause monitoring section
            Section {
                Toggle("Pause Clipboard Monitoring", isOn: $privacy.isMonitoringPaused)

                if privacy.isMonitoringPaused {
                    Label("Monitoring is paused. No new items will be captured.", systemImage: "pause.circle.fill")
                        .font(AureliaDesign.Typography.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Monitoring")
            }

            // Ignored apps section
            Section {
                if privacy.ignoredApps.isEmpty {
                    Text("No apps ignored")
                        .foregroundStyle(AureliaColors.secondaryText)
                        .italic()
                } else {
                    ForEach(privacy.ignoredApps) { app in
                        HStack {
                            AppIconView(bundleID: app.bundleID)
                                .frame(width: 24, height: 24)

                            Text(app.appName)
                                .font(AureliaDesign.Typography.body)

                            Spacer()

                            Button {
                                privacy.removeIgnoredApp(bundleID: app.bundleID)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    Button("Add Application...") {
                        showingAppPicker = true
                    }

                    Spacer()

                    Button("Add Password Managers") {
                        privacy.addDefaultPasswordManagers()
                    }
                    .foregroundStyle(AureliaColors.accent)
                }
            } header: {
                Text("Ignored Applications")
            } footer: {
                Text("Clipboard content from these apps will not be captured. This is useful for password managers and other sensitive applications.")
                    .font(AureliaDesign.Typography.caption)
                    .foregroundStyle(AureliaColors.secondaryText)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingAppPicker) {
            AppPickerSheet(privacy: privacy) {
                showingAppPicker = false
            }
        }
    }
}

// MARK: - App Icon View

struct AppIconView: View {
    let bundleID: String

    var body: some View {
        if let icon = getAppIcon() {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "app.fill")
                .foregroundStyle(AureliaColors.secondaryText)
        }
    }

    private func getAppIcon() -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// MARK: - App Picker Sheet

struct AppPickerSheet: View {
    let privacy: PrivacyManager
    let onDismiss: () -> Void

    @State private var searchText = ""

    var filteredApps: [NSRunningApplication] {
        let apps = privacy.getRunningApps()
        if searchText.isEmpty {
            return apps
        }
        return apps.filter {
            ($0.localizedName ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Select Application")
                    .font(AureliaDesign.Typography.headline)
                Spacer()
                Button("Done") {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AureliaColors.secondaryText)
                TextField("Search running apps...", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(AureliaDesign.Spacing.sm)
            .background(AureliaColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AureliaDesign.Radius.md))
            .padding()

            // App list
            List {
                ForEach(filteredApps, id: \.bundleIdentifier) { app in
                    if let bundleID = app.bundleIdentifier,
                       let name = app.localizedName {
                        HStack {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 24, height: 24)
                            }

                            Text(name)
                                .font(AureliaDesign.Typography.body)

                            Spacer()

                            if privacy.isAppIgnored(bundleID: bundleID) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AureliaColors.accent)
                            } else {
                                Button("Add") {
                                    privacy.addIgnoredApp(bundleID: bundleID, appName: name)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, AureliaDesign.Spacing.xs)
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }
}

#Preview {
    PrivacySettingsView()
}
