import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var vm: WeatherViewModel
    @State private var stations: [(id: String, name: String)] = []
    @State private var loadingStations = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Toggle("Imperial (°F / mph)", isOn: $store.settings.useImperial)
                }

                Section {
                    SecureField("Personal Access Token", text: $store.settings.apiToken)
                        .textContentType(.password)
                        .autocapitalization(.none)
                    Text("Optional. Get a free token at tempestwx.com → Account → Personal Use Token. Required for REST fallback when UDP is unavailable.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !store.settings.apiToken.isEmpty {
                        Button {
                            loadingStations = true
                            Task {
                                stations = await vm.discoverStations()
                                loadingStations = false
                            }
                        } label: {
                            HStack {
                                Text("Find my stations")
                                if loadingStations { Spacer(); ProgressView() }
                            }
                        }

                        if !stations.isEmpty {
                            Picker("Station", selection: $store.settings.stationId) {
                                Text("None").tag("")
                                ForEach(stations, id: \.id) { s in
                                    Text(s.name).tag(s.id)
                                }
                            }
                        } else {
                            TextField("Station ID (manual)", text: $store.settings.stationId)
                                .keyboardType(.numberPad)
                        }
                    }
                } header: {
                    Text("WeatherFlow API (optional)")
                }

                Section("Glasses (TCP :8088)") {
                    LabeledContent("Port", value: "8088")
                    Text("Connect your Rokid glasses client to this phone's IP on TCP port 8088. Each message is a JSON object followed by \\n.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("UDP Reception") {
                    LabeledContent("Listening on", value: "UDP :50222")
                    HStack {
                        Circle()
                            .fill(vm.udpReceiving ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(vm.udpReceiving ? "Receiving packets" : "No packets — check that phone and Tempest Hub are on same Wi-Fi")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
