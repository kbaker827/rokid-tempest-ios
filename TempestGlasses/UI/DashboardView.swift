import SwiftUI

struct DashboardView: View {
    @ObservedObject var vm: WeatherViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroCard
                windCard
                skyCard
                precipCard
                if !vm.strikeHistory.isEmpty { lightningCard }
                pressureCard
                if !vm.recentAlerts.isEmpty { alertsCard }
            }
            .padding()
        }
    }

    // MARK: - Cards

    private var heroCard: some View {
        VStack(spacing: 4) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.formattedTemp(vm.weather.tempC))
                        .font(.system(size: 64, weight: .thin, design: .rounded))
                    Text("Feels like \(vm.formattedTemp(vm.weather.feelsLikeC))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HumidityBadge(rh: vm.weather.humidity)
                    if vm.weather.batteryV > 0 {
                        BatteryBadge(voltage: vm.weather.batteryV)
                    }
                }
            }
            .padding(.horizontal)

            Divider()

            HStack {
                Label(vm.statusText, systemImage: vm.udpReceiving ? "antenna.radiowaves.left.and.right" : "wifi.slash")
                    .font(.caption)
                    .foregroundColor(vm.udpReceiving ? .green : .orange)
                Spacer()
                if vm.weather.lastObsAt != nil {
                    Text("UV \(String(format: "%.1f", vm.weather.uvIndex))")
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(uvColor(vm.weather.uvIndex).opacity(0.2))
                        .foregroundColor(uvColor(vm.weather.uvIndex))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
    }

    private var windCard: some View {
        WeatherCard(title: "Wind", icon: "wind") {
            VStack(spacing: 12) {
                HStack {
                    WindMetric(label: "Avg", value: vm.formattedWind(vm.weather.windAvgMs))
                    Divider().frame(height: 40)
                    WindMetric(label: "Gust", value: vm.formattedWind(vm.weather.windGustMs))
                    Divider().frame(height: 40)
                    WindMetric(label: "Lull", value: vm.formattedWind(vm.weather.windLullMs))
                }
                HStack {
                    CompassView(degrees: Double(vm.weather.windDirectionDeg))
                        .frame(width: 60, height: 60)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(vm.weather.windBearing) — \(vm.weather.windDirectionDeg)°")
                            .font(.headline)
                        if vm.weather.lastRapidWindAt != nil {
                            Text("Rapid: \(vm.formattedWind(vm.weather.rapidWindMs))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private var skyCard: some View {
        WeatherCard(title: "Sky", icon: "sun.max.fill") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MiniStat(label: "UV Index", value: String(format: "%.1f", vm.weather.uvIndex), color: uvColor(vm.weather.uvIndex))
                MiniStat(label: "Solar", value: String(format: "%.0f W/m²", vm.weather.solarRadiation), color: .orange)
                MiniStat(label: "Illuminance", value: String(format: "%.0f lux", vm.weather.illuminanceLux), color: .yellow)
                MiniStat(label: "Dew Point", value: vm.formattedTemp(FeelsLike.dewPoint(tempC: vm.weather.tempC, rh: vm.weather.humidity)), color: .teal)
            }
        }
    }

    private var precipCard: some View {
        WeatherCard(title: "Precipitation", icon: "drop.fill") {
            HStack {
                MiniStat(label: "Today", value: String(format: "%.1f mm", vm.weather.rainAccumulatedMm), color: .blue)
                Divider().frame(height: 40)
                MiniStat(label: "Type", value: vm.weather.precipLabel,
                         color: vm.weather.precipType > 0 ? .blue : .secondary)
            }
        }
    }

    private var lightningCard: some View {
        WeatherCard(title: "Lightning", icon: "bolt.fill") {
            HStack {
                MiniStat(label: "Last hour", value: "\(vm.strikeHistory.count) strikes", color: .yellow)
                Divider().frame(height: 40)
                if let last = vm.weather.lastStrikeAt {
                    MiniStat(label: "Last strike", value: "\(Int(vm.weather.lastStrikeDistKm)) km", color: .orange)
                }
            }
        }
    }

    private var pressureCard: some View {
        WeatherCard(title: "Pressure", icon: "barometer") {
            HStack {
                MiniStat(label: "Station", value: String(format: "%.1f mb", vm.weather.stationPressureMb), color: .purple)
                if vm.weather.batteryV > 0 {
                    Divider().frame(height: 40)
                    MiniStat(label: "Battery", value: String(format: "%.2f V", vm.weather.batteryV), color: batteryColor(vm.weather.batteryV))
                }
            }
        }
    }

    private var alertsCard: some View {
        WeatherCard(title: "Alerts", icon: "exclamationmark.triangle.fill") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(vm.recentAlerts.prefix(5), id: \.self) { alert in
                    Text(alert).font(.subheadline)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func uvColor(_ uv: Double) -> Color {
        switch uv {
        case ..<3:  return .green
        case ..<6:  return .yellow
        case ..<8:  return .orange
        case ..<11: return .red
        default:    return .purple
        }
    }

    private func batteryColor(_ v: Double) -> Color {
        if v > 2.8 { return .green }
        if v > 2.5 { return .orange }
        return .red
    }
}

// MARK: - Sub-components

struct WeatherCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
    }
}

struct MiniStat: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.headline).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WindMetric: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity)
    }
}

struct HumidityBadge: View {
    let rh: Double
    var body: some View {
        Label(String(format: "%.0f%%", rh), systemImage: "humidity.fill")
            .font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.blue.opacity(0.15))
            .foregroundColor(.blue)
            .clipShape(Capsule())
    }
}

struct BatteryBadge: View {
    let voltage: Double
    var body: some View {
        Label(String(format: "%.2fV", voltage), systemImage: "battery.75")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

struct CompassView: View {
    let degrees: Double
    var body: some View {
        ZStack {
            Circle().stroke(Color(.systemGray4), lineWidth: 1)
            Image(systemName: "arrow.up")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.accentColor)
                .rotationEffect(.degrees(degrees))
        }
    }
}
