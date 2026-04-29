import Foundation

// MARK: - Live weather state (built from UDP packets)

struct WeatherState {
    // Temperature & humidity
    var tempC: Double = 0
    var humidity: Double = 0
    var feelsLikeC: Double = 0

    // Wind (m/s → converted on display)
    var windAvgMs: Double = 0
    var windGustMs: Double = 0
    var windLullMs: Double = 0
    var windDirectionDeg: Int = 0

    // Rapid wind (updates every 3s)
    var rapidWindMs: Double = 0
    var rapidWindDeg: Int = 0

    // Pressure
    var stationPressureMb: Double = 0

    // Sky
    var uvIndex: Double = 0
    var solarRadiation: Double = 0
    var illuminanceLux: Double = 0

    // Rain
    var rainAccumulatedMm: Double = 0
    var precipType: Int = 0  // 0=none 1=rain 2=hail 3=rain+hail

    // Lightning
    var lightningCount: Int = 0
    var lightningAvgDistKm: Int = 0
    var lastStrikeAt: Date?
    var lastStrikeDistKm: Double = 0

    // Status
    var batteryV: Double = 0
    var lastObsAt: Date?
    var lastRapidWindAt: Date?
    var serialNumber: String = ""

    // Derived
    var tempF: Double { tempC * 9 / 5 + 32 }
    var feelsLikeF: Double { feelsLikeC * 9 / 5 + 32 }
    var windAvgMph: Double { windAvgMs * 2.23694 }
    var windGustMph: Double { windGustMs * 2.23694 }
    var windAvgKmh: Double { windAvgMs * 3.6 }
    var windGustKmh: Double { windGustMs * 3.6 }

    var precipLabel: String {
        switch precipType {
        case 1: return "Rain"
        case 2: return "Hail"
        case 3: return "Rain+Hail"
        default: return "None"
        }
    }

    var windBearing: String {
        let dirs = ["N","NNE","NE","ENE","E","ESE","SE","SSE","S","SSW","SW","WSW","W","WNW","NW","NNW"]
        let idx = Int((Double(windDirectionDeg) + 11.25) / 22.5) % 16
        return dirs[idx]
    }
}

// MARK: - UDP packet types

enum TempestPacket {
    case obsSt(ObsStPacket)
    case rapidWind(RapidWindPacket)
    case evtStrike(StrikePacket)
    case evtPrecip(Date)
    case deviceStatus(DeviceStatusPacket)
    case unknown

    static func parse(json: [String: Any]) -> TempestPacket {
        guard let type = json["type"] as? String else { return .unknown }
        switch type {
        case "obs_st":    return ObsStPacket.parse(json).map { .obsSt($0) } ?? .unknown
        case "rapid_wind": return RapidWindPacket.parse(json).map { .rapidWind($0) } ?? .unknown
        case "evt_strike": return StrikePacket.parse(json).map { .evtStrike($0) } ?? .unknown
        case "evt_precip": return .evtPrecip(Date())
        case "device_status": return DeviceStatusPacket.parse(json).map { .deviceStatus($0) } ?? .unknown
        default: return .unknown
        }
    }
}

struct ObsStPacket {
    let timestamp: Date
    let windLull: Double        // m/s
    let windAvg: Double         // m/s
    let windGust: Double        // m/s
    let windDir: Int            // degrees
    let pressure: Double        // mb
    let tempC: Double
    let humidity: Double
    let illuminance: Double     // lux
    let uv: Double
    let solarRadiation: Double  // W/m²
    let rainMm: Double
    let precipType: Int
    let lightningDist: Int      // km
    let lightningCount: Int
    let battery: Double         // V

    // Indices in obs array
    static func parse(_ json: [String: Any]) -> ObsStPacket? {
        guard let obs = (json["obs"] as? [[Any]])?.first, obs.count >= 17 else { return nil }
        return ObsStPacket(
            timestamp: Date(timeIntervalSince1970: (obs[0] as? Double) ?? 0),
            windLull: (obs[1] as? Double) ?? 0,
            windAvg: (obs[2] as? Double) ?? 0,
            windGust: (obs[3] as? Double) ?? 0,
            windDir: (obs[4] as? Int) ?? 0,
            pressure: (obs[6] as? Double) ?? 0,
            tempC: (obs[7] as? Double) ?? 0,
            humidity: (obs[8] as? Double) ?? 0,
            illuminance: (obs[9] as? Double) ?? 0,
            uv: (obs[10] as? Double) ?? 0,
            solarRadiation: (obs[11] as? Double) ?? 0,
            rainMm: (obs[12] as? Double) ?? 0,
            precipType: (obs[13] as? Int) ?? 0,
            lightningDist: (obs[14] as? Int) ?? 0,
            lightningCount: (obs[15] as? Int) ?? 0,
            battery: (obs[16] as? Double) ?? 0
        )
    }
}

struct RapidWindPacket {
    let timestamp: Date
    let speedMs: Double
    let directionDeg: Int

    static func parse(_ json: [String: Any]) -> RapidWindPacket? {
        guard let obs = json["ob"] as? [Any], obs.count >= 3 else { return nil }
        return RapidWindPacket(
            timestamp: Date(timeIntervalSince1970: (obs[0] as? Double) ?? 0),
            speedMs: (obs[1] as? Double) ?? 0,
            directionDeg: (obs[2] as? Int) ?? 0
        )
    }
}

struct StrikePacket {
    let timestamp: Date
    let distanceKm: Double
    let energy: Double

    static func parse(_ json: [String: Any]) -> StrikePacket? {
        guard let evt = json["evt"] as? [Any], evt.count >= 3 else { return nil }
        return StrikePacket(
            timestamp: Date(timeIntervalSince1970: (evt[0] as? Double) ?? 0),
            distanceKm: (evt[1] as? Double) ?? 0,
            energy: (evt[2] as? Double) ?? 0
        )
    }
}

struct DeviceStatusPacket {
    let serialNumber: String
    let battery: Double
    let uptime: Int

    static func parse(_ json: [String: Any]) -> DeviceStatusPacket? {
        guard let sn = json["serial_number"] as? String else { return nil }
        return DeviceStatusPacket(
            serialNumber: sn,
            battery: (json["voltage"] as? Double) ?? 0,
            uptime: (json["uptime"] as? Int) ?? 0
        )
    }
}

// MARK: - REST API models

struct StationObservation: Decodable {
    let obs: [StationObs]

    struct StationObs: Decodable {
        let timestamp: Int
        let windAvg: Double?
        let windGust: Double?
        let windDirection: Double?
        let windLull: Double?
        let pressure: Double?
        let airTemperature: Double?
        let relativeHumidity: Double?
        let illuminance: Double?
        let uv: Double?
        let solarRadiation: Double?
        let rainAccumulated: Double?
        let precipitationType: Double?
        let lightningStrikeAvgDistance: Double?
        let lightningStrikeCount: Double?
        let feelsLike: Double?
        let dewPoint: Double?
        let wetBulbTemperature: Double?

        enum CodingKeys: String, CodingKey {
            case timestamp
            case windAvg = "wind_avg"
            case windGust = "wind_gust"
            case windDirection = "wind_direction"
            case windLull = "wind_lull"
            case pressure = "station_pressure"
            case airTemperature = "air_temperature"
            case relativeHumidity = "relative_humidity"
            case illuminance
            case uv
            case solarRadiation = "solar_radiation"
            case rainAccumulated = "rain_accumulated"
            case precipitationType = "precipitation_type"
            case lightningStrikeAvgDistance = "lightning_strike_avg_distance"
            case lightningStrikeCount = "lightning_strike_count"
            case feelsLike = "feels_like"
            case dewPoint = "dew_point"
            case wetBulbTemperature = "wet_bulb_temperature"
        }
    }
}
