import SwiftUI

struct ContentView: View {
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var vm: WeatherViewModel
    @State private var selectedTab = 0
    @State private var showSettings = false

    init() {
        let ss = SettingsStore()
        _settingsStore = StateObject(wrappedValue: ss)
        _vm = StateObject(wrappedValue: WeatherViewModel(settingsStore: ss))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DashboardView(vm: vm)
                    .navigationTitle("Tempest")
                    .navigationBarTitleDisplayMode(.large)
                    .toolbar { toolbarItems }
                    .background(Color(.systemGroupedBackground))
            }
            .tabItem { Label("Weather", systemImage: "cloud.sun.fill") }
            .tag(0)

            NavigationStack {
                GlassesPreviewView(vm: vm)
                    .navigationTitle("Glasses Display")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { toolbarItems }
            }
            .tabItem { Label("Glasses", systemImage: "eyeglasses") }
            .tag(1)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: settingsStore, vm: vm)
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            glassesIndicator
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
            }
        }
    }

    private var glassesIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(vm.glassesConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
            Text(vm.glassesConnected
                 ? "\(vm.glassesClientCount) glasses"
                 : "No glasses")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
