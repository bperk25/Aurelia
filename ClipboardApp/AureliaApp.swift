//
//  AureliaApp.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/1/25.
//

import SwiftUI

@main
struct AureliaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: AureliaDesign.Layout.minWindowWidth,
                     height: AureliaDesign.Layout.minWindowHeight)

        Settings {
            SettingsView()
        }
    }
}
