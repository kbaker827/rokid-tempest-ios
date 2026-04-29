import Foundation
import Combine

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published var weather = WeatherState()
    @Published var udpReceiving = false
    @Published var lastPacketAge: TimeInterval = 0
    @Published var glassesConnected = false
    @Published var glassesClientCount = 0
    @Published var statusText = "Waiting for Tempest Hub..."
    @Published var recentAlerts: [String] = []

    // Strike history for the last hour
    @Published var strikeHistory: [(date: Date, distKm: Double)] = []

    let settingsStore: SettingsStore

    private let udpReceiver = TempestUDPReceiver()
    private let glassesServer = GlassesServer()
    private var broadcastTimer: Timer?
    private var ageTimer: Timer?
    private var restFallbackTask: Task<Void, Never>?

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        setupGlassesServer()
        setupUDP()
        startTimers()
        glassesServer.start()
    }

    // MARK: - Setup

    private func setupGlassesServer() {
        glassesServer.onClientConnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                glassesClientCount = glassesServer.clientCount
                glassesConnected = true
                // Send current state immediately on connect
                broadcastToGlasses()
            }
        }
        glassesServer.onClientDisconnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                glassesClientCount = glassesServer.clientCount
                glassesConnected = glassesClientCount > 0
            }
        }
    }

    private func setupUDP() {
        udpReceiver.onPacket = { [weak self] packet in
            self?.handlePacket(packet)
        }
        udpReceiver.start()
    }

    private func startTimers() {
        // Broadcast to glasses every 3 seconds
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.broadcastToGlasses() }
        }
        // Track how stale the last packet is
        ageTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let last = weather.lastObsAt {
                    lastPacketAge = Date().timeIntervalSince(last)
                    udpReceiving = lastPacketAge < 120
                    if !udpReceiving && !settingsStore.settings.apiToken.isEmpty {
                        scheduleRestFallback()
                    }
                }
            }
        }
    }

    // MARK: - Packet handling

    private func handlePacket(_ packet: TempestPacket) {
        switch packet {
        case .obsSt(let obs):
            weather.windLullMs = obs.windLull
            weather.windAvgMs = obs.windAvg
            weather.windGustMs = obs.windGust
            weather.windDirectionDeg = obs.windDir
            weather.stationPressureMb = obs.pressure
            weather.tempC = obs.tempC
            weather.humidity = obs.humidity
            weather.illuminanceLux = obs.illuminance
            weather.uvIndex = obs.uv
            weather.solarRadiation = obs.solarRadiation
            weather.rainAccumulatedMm = obs.rainMm
            weather.precipType = obs.precipType
            weather.lightningAvgDistKm = obs.lightningDist
            weather.lightningCount = obs.lightningCount
            weather.batteryV = obs.battery
            weather.lastObsAt = obs.timestamp
            weather.feelsLikeC = FeelsLike.feelsLike(tempC: obs.tempC, rh: obs.humidity, windMs: obs.windAvg)
            statusText = "Live — updated \(timeAgo(obs.timestamp))"
            udpReceiving = true

        case .rapidWind(let rw):
            weather.rapidWindMs = rw.speedMs
            weather.rapidWindDeg = rw.directionDeg
            weather.lastRapidWindAt = rw.timestamp

        case .evtStrike(let strike):
            weather.lastStrikeAt = strike.timestamp
            weather.lastStrikeDistKm = strike.distanceKm
            let alert = "⚡ Lightning \(Int(strike.distanceKm)) km away"
            if recentAlerts.first != alert { recentAlerts.insert(alert, at: 0) }
            if recentAlerts.count > 10 { recentAlerts.removeLast() }
            strikeHistory.append((date: strike.timestamp, distKm: strike.distanceKm))
            strikeHistory = strikeHistory.filter { Date().timeIntervalSince($0.date) < 3600 }
            glassesServer.broadcastAlert(alert)

        case .evtPrecip:
            let alert = "🌧 Rain started"
            if recentAlerts.first != alert { recentAlerts.insert(alert, at: 0) }
            glassesServer.broadcastAlert(alert)

        case .deviceStatus(let status):
            weather.serialNumber = status.serialNumber
            weather.batteryV = status.battery

        case .unknown:
            break
        }
    }

    // MARK: - Glasses broadcast

    private func broadcastToGlasses() {
        guard glassesConnected else { return }

        let s = settingsStore.settings
        let text = formatForGlasses(format: s.glassesFormat, imperial: s.useImperial)
        glassesServer.broadcastFormatted(text)

        // Also send full JSON payload
        let payload = buildFullPayload(imperial: s.useImperial)
        glassesServer.broadcastWeather(payload)
    }

    func formatForGlasses(format: AppSettings.GlassesFormat, imperial: Bool) -> String {
        let temp = imperial
            ? String(format: "%.0f°F", weather.tempF)
            : String(format: "%.1f°C", weather.tempC)
        let wind = imperial
            ? String(format: "%@ %.0f mph", weather.windBearing, weather.windAvgMph)
            : String(format: "%@ %.0f km/h", weather.windBearing, weather.windAvgKmh)
        let uv = String(format: "UV %.1f", weather.uvIndex)
        let precip = weather.precipType > 0 ? weather.precipLabel : (weather.rainAccumulatedMm > 0 ? String(format: "%.1f mm", weather.rainAccumulatedMm) : "Dry")
        let lightning = strikeHistory.isEmpty ? "" : " ⚡\(strikeHistory.count)"

        switch format {
        case .compact:
            return "\(temp)  \(wind)  \(uv)  \(precip)\(lightning)"
        case .minimal:
            return "\(temp)  \(wind)"
        case .multiline:
            var lines = [temp, wind, uv, precip]
            if !strikeHistory.isEmpty { lines.append("⚡ \(strikeHistory.count) strikes (1h)") }
            return lines.joined(separator: "\n")
        }
    }

    private func buildFullPayload(imperial: Bool) -> [String: Any] {
        [
            "type": "obs",
            "tempC": weather.tempC,
            "tempF": weather.tempF,
            "humidity": weather.humidity,
            "feelsLikeC": weather.feelsLikeC,
            "feelsLikeF": weather.feelsLikeF,
            "windAvgMs": weather.windAvgMs,
            "windAvgMph": weather.windAvgMph,
            "windGustMs": weather.windGustMs,
            "windGustMph": weather.windGustMph,
            "windBearing": weather.windBearing,
            "windDirectionDeg": weather.windDirectionDeg,
            "rapidWindMs": weather.rapidWindMs,
            "pressureMb": weather.stationPressureMb,
            "uv": weather.uvIndex,
            "solarRadiation": weather.solarRadiation,
            "illuminance": weather.illuminanceLux,
            "rainMm": weather.rainAccumulatedMm,
            "precipType": weather.precipType,
            "lightningCount": weather.lightningCount,
            "lightningDistKm": weather.lightningAvgDistKm,
            "strikesLastHour": strikeHistory.count,
            "batteryV": weather.batteryV,
            "timestamp": weather.lastObsAt?.timeIntervalSince1970 ?? 0
        ]
    }

    // MARK: - REST fallback

    private var lastRestFetch = Date.distantPast
    private func scheduleRestFallback() {
        guard Date().timeIntervalSince(lastRestFetch) > 60 else { return }
        lastRestFetch = Date()
        let s = settingsStore.settings
        guard !s.apiToken.isEmpty, !s.stationId.isEmpty else { return }
        restFallbackTask?.cancel()
        restFallbackTask = Task {
            guard let obs = try? await TempestRestClient.fetchLatestObservation(
                stationId: s.stationId, token: s.apiToken),
                  let latest = obs.obs.first else { return }
            await MainActor.run {
                weather.tempC = latest.airTemperature ?? weather.tempC
                weather.humidity = latest.relativeHumidity ?? weather.humidity
                weather.windAvgMs = latest.windAvg ?? weather.windAvgMs
                weather.windGustMs = latest.windGust ?? weather.windGustMs
                weather.windDirectionDeg = Int(latest.windDirection ?? Double(weather.windDirectionDeg))
                weather.uvIndex = latest.uv ?? weather.uvIndex
                weather.rainAccumulatedMm = latest.rainAccumulated ?? weather.rainAccumulatedMm
                weather.stationPressureMb = latest.pressure ?? weather.stationPressureMb
                weather.feelsLikeC = latest.feelsLike ?? weather.feelsLikeC
                weather.lastObsAt = Date(timeIntervalSince1970: TimeInterval(latest.timestamp))
                statusText = "REST API — updated \(timeAgo(Date()))"
            }
        }
    }

    // MARK: - Auto-discover station ID

    func discoverStations() async -> [(id: String, name: String)] {
        let token = settingsStore.settings.apiToken
        guard !token.isEmpty,
              let stations = try? await TempestRestClient.fetchStations(token: token) else { return [] }
        return stations.compactMap { s in
            guard let id = (s["station_id"] as? Int).map(String.init),
                  let name = s["name"] as? String else { return nil }
            return (id: id, name: name)
        }
    }

    // MARK: - Helpers

    private func timeAgo(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "\(s)s ago" }
        return "\(s / 60)m ago"
    }

    func formattedTemp(_ c: Double) -> String {
        settingsStore.settings.useImperial
            ? String(format: "%.0f°F", c * 9 / 5 + 32)
            : String(format: "%.1f°C", c)
    }

    func formattedWind(_ ms: Double) -> String {
        settingsStore.settings.useImperial
            ? String(format: "%.0f mph", ms * 2.23694)
            : String(format: "%.0f km/h", ms * 3.6)
    }
}
