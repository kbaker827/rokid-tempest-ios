import Foundation

// WeatherFlow REST API — requires a personal access token from tempestwx.com
// https://weatherflow.github.io/Tempest/api/
enum TempestRestClient {
    private static let base = "https://swd.weatherflow.com/swd/rest"

    // Fetch latest observation for a station (fallback when UDP is unavailable)
    static func fetchLatestObservation(stationId: String, token: String) async throws -> StationObservation {
        guard !stationId.isEmpty, !token.isEmpty else {
            throw RestError.missingCredentials
        }
        guard let url = URL(string: "\(base)/observations/station/\(stationId)?token=\(token)") else {
            throw RestError.badURL
        }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("TempestGlasses/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RestError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(StationObservation.self, from: data)
    }

    // Fetch stations associated with a token to auto-populate the station ID
    static func fetchStations(token: String) async throws -> [[String: Any]] {
        guard !token.isEmpty else { throw RestError.missingCredentials }
        guard let url = URL(string: "\(base)/stations?token=\(token)") else { throw RestError.badURL }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("TempestGlasses/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let stations = json["stations"] as? [[String: Any]] else { return [] }
        return stations
    }

    enum RestError: LocalizedError {
        case missingCredentials, badURL, httpError(Int)
        var errorDescription: String? {
            switch self {
            case .missingCredentials: return "API token and station ID required"
            case .badURL: return "Invalid API URL"
            case .httpError(let code): return "HTTP \(code)"
            }
        }
    }
}
