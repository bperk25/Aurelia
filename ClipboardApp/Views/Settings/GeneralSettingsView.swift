//
//  GeneralSettingsView.swift
//  Aurelia
//
//  Created by Bryant Perkins on 1/4/25.
//

import SwiftUI

struct GeneralSettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var sliderIndex: Double

    private let retentionOptions = RetentionPeriod.sliderCases

    init() {
        let currentIndex = RetentionPeriod.sliderCases.firstIndex(of: AppSettings.shared.retentionPeriod) ?? 2
        _sliderIndex = State(initialValue: Double(currentIndex))
    }

    var body: some View {
        Form {
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

#Preview {
    GeneralSettingsView()
}
