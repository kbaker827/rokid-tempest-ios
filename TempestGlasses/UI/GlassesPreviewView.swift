import SwiftUI

// Shows exactly what the glasses will display, live-updating
struct GlassesPreviewView: View {
    @ObservedObject var vm: WeatherViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Connection status
            HStack {
                Circle()
                    .fill(vm.glassesConnected ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(vm.glassesConnected
                     ? "\(vm.glassesClientCount) glasses connected on TCP :8088"
                     : "No glasses — connect to TCP :\(GlassesServer.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Glasses screen mockup
            VStack(alignment: .leading, spacing: 0) {
                // Status bar
                HStack {
                    Image(systemName: "wifi")
                    Spacer()
                    Image(systemName: "battery.75")
                }
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom, 6)

                // Weather content
                let format = vm.settingsStore.settings.glassesFormat
                let imperial = vm.settingsStore.settings.useImperial
                let text = vm.formatForGlasses(format: format, imperial: imperial)

                if format == .multiline {
                    ForEach(text.components(separatedBy: "\n"), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                    }
                } else {
                    Text(text)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.4), radius: 8)

            // Format picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Display format")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Picker("Format", selection: $vm.settingsStore.settings.glassesFormat) {
                    ForEach(AppSettings.GlassesFormat.allCases, id: \.self) { fmt in
                        Text(fmt.rawValue.capitalized).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Full JSON payload preview
            GroupBox("Raw JSON (TCP)") {
                ScrollView {
                    Text(prettyJSON)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
            }
        }
        .padding()
    }

    private var prettyJSON: String {
        let payload: [String: Any] = [
            "type": "obs",
            "tempC": String(format: "%.1f", vm.weather.tempC),
            "tempF": String(format: "%.0f", vm.weather.tempF),
            "humidity": String(format: "%.0f", vm.weather.humidity),
            "windAvgMph": String(format: "%.0f", vm.weather.windAvgMph),
            "windBearing": vm.weather.windBearing,
            "uv": String(format: "%.1f", vm.weather.uvIndex),
            "rainMm": String(format: "%.1f", vm.weather.rainAccumulatedMm),
            "pressureMb": String(format: "%.1f", vm.weather.stationPressureMb),
            "lightningCount": vm.weather.lightningCount
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}
