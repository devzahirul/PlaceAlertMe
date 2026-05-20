import SwiftUI

struct SettingsScreen: View {
    @State private var notificationsEnabled = true
    @State private var backgroundTrackingEnabled = true
    @State private var batteryOptimization = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "notificationsEnabled")
                        }

                    Text("Receive notifications when entering or leaving geofence zones")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Section("Location Tracking") {
                    Toggle("Background Tracking", isOn: $backgroundTrackingEnabled)
                        .onChange(of: backgroundTrackingEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "backgroundTrackingEnabled")
                        }

                    Text("Allow tracking when app is in background")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Section("Battery") {
                    Toggle("Battery Optimization", isOn: $batteryOptimization)
                        .onChange(of: batteryOptimization) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "batteryOptimization")
                        }

                    Text("Reduce location accuracy to save battery")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text("2024.05.20")
                            .foregroundColor(.gray)
                    }

                    HStack {
                        Text("Platform")
                        Spacer()
                        Text("iOS 14+")
                            .foregroundColor(.gray)
                    }
                }

                Section("About") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PlaceAlertMe Example")
                            .font(.headline)

                        Text("A comprehensive example app demonstrating the PlaceAlertMe geofencing library with SwiftUI, MapKit integration, and adaptive location tracking.")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text("Features:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.top, 8)

                        VStack(alignment: .leading, spacing: 4) {
                            Label("SwiftUI Interface", systemImage: "square.and.pencil")
                            Label("MapKit Integration", systemImage: "map.fill")
                            Label("Adaptive Tracking", systemImage: "location.fill")
                            Label("Geofence Management", systemImage: "circle.fill")
                            Label("Battery Optimization", systemImage: "bolt.fill")
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                    }
                    .padding(.vertical, 8)
                }

                Section("Quick Start") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(.purple)
                            Text("Toggle tracking on Home screen")
                                .font(.caption)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "2.circle.fill")
                                .foregroundColor(.purple)
                            Text("Create zones manually or via map")
                                .font(.caption)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "3.circle.fill")
                                .foregroundColor(.purple)
                            Text("Adjust zone radius (100-5000m)")
                                .font(.caption)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "4.circle.fill")
                                .foregroundColor(.purple)
                            Text("Receive notifications on entry/exit")
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Example Coordinates") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("San Francisco")
                                .font(.caption)
                                .fontWeight(.semibold)
                            HStack {
                                Text("37.7749, -122.4194")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("1000m")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("New York")
                                .font(.caption)
                                .fontWeight(.semibold)
                            HStack {
                                Text("40.7128, -74.0060")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("1000m")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Los Angeles")
                                .font(.caption)
                                .fontWeight(.semibold)
                            HStack {
                                Text("34.0522, -118.2437")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("1000m")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                loadSettings()
            }
        }
    }

    private func loadSettings() {
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled") || true
        backgroundTrackingEnabled = UserDefaults.standard.bool(forKey: "backgroundTrackingEnabled") || true
        batteryOptimization = UserDefaults.standard.bool(forKey: "batteryOptimization") || true
    }
}

#Preview {
    SettingsScreen()
}
