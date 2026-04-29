import Foundation

struct AppSettings: Codable {
    var useImperial: Bool = true          // °F / mph
    var apiToken: String = ""             // WeatherFlow personal access token
    var stationId: String = ""            // Station ID for REST fallback
    var glassesFormat: GlassesFormat = .compact

    enum GlassesFormat: String, Codable, CaseIterable {
        case compact   // "72°F | WSW 8 mph | UV 3.2 | 💧 None"
        case multiline // one metric per line
        case minimal   // just temp + wind
    }
}

final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "tempest_settings"),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
        } else {
            settings = AppSettings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "tempest_settings")
        }
    }
}
