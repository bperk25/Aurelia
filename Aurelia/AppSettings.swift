import Foundation
import ServiceManagement

// MARK: - Panel View Mode

enum PanelViewMode: String, CaseIterable {
    case list = "list"
    case thumbnail = "thumbnail"

    var displayName: String {
        switch self {
        case .list: return "List"
        case .thumbnail: return "Thumbnail"
        }
    }

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .thumbnail: return "square.grid.2x2"
        }
    }
}

// MARK: - Retention Period

enum RetentionPeriod: Int, CaseIterable {
    case oneDay = 1
    case threeDays = 3
    case oneWeek = 7
    case twoWeeks = 14
    case oneMonth = 30
    case forever = -1

    var displayName: String {
        switch self {
        case .oneDay: return "1 Day"
        case .threeDays: return "3 Days"
        case .oneWeek: return "1 Week"
        case .twoWeeks: return "2 Weeks"
        case .oneMonth: return "1 Month"
        case .forever: return "Forever"
        }
    }

    var days: Int? {
        self == .forever ? nil : rawValue
    }

    static var sliderCases: [RetentionPeriod] {
        [.oneDay, .threeDays, .oneWeek, .twoWeeks, .oneMonth, .forever]
    }
}

// MARK: - App Settings

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    private let retentionKey = "clipboardRetentionPeriod"
    private let panelViewModeKey = "panelViewMode"

    var retentionPeriod: RetentionPeriod {
        didSet {
            defaults.set(retentionPeriod.rawValue, forKey: retentionKey)
        }
    }

    var panelViewMode: PanelViewMode {
        didSet {
            defaults.set(panelViewMode.rawValue, forKey: panelViewModeKey)
        }
    }

    var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }

    private init() {
        let savedValue = defaults.integer(forKey: retentionKey)
        if savedValue == 0 {
            // Default to 1 week if not set
            self.retentionPeriod = .oneWeek
        } else {
            self.retentionPeriod = RetentionPeriod(rawValue: savedValue) ?? .oneWeek
        }

        // Load panel view mode (default to thumbnail)
        if let savedViewMode = defaults.string(forKey: panelViewModeKey),
           let viewMode = PanelViewMode(rawValue: savedViewMode) {
            self.panelViewMode = viewMode
        } else {
            self.panelViewMode = .thumbnail
        }
    }

    func shouldKeepItem(copiedAt date: Date) -> Bool {
        guard let days = retentionPeriod.days else {
            return true // Forever
        }
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return date > cutoffDate
    }
}
