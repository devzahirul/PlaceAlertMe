import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var manualLatitude = ""
    @State private var manualLongitude = ""
    @State private var manualRadius = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Tracking Status Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tracking Status")
                                .font(.headline)
                                .foregroundColor(.gray)

                            HStack(spacing: 8) {
                                Circle()
                                    .fill(viewModel.isTracking ? Color.green : Color.red)
                                    .frame(width: 12, height: 12)

                                Text(viewModel.isTracking ? "Active" : "Inactive")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                        }

                        Spacer()

                        Toggle("", isOn: $viewModel.isTracking)
                            .onChange(of: viewModel.isTracking) { _, newValue in
                                newValue ? viewModel.startTracking() : viewModel.stopTracking()
                            }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Zone Statistics Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Active Zones")
                                .font(.headline)
                                .foregroundColor(.gray)

                            Text("\(viewModel.zones.count)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }

                        Spacer()

                        Image(systemName: "map.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.purple)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: { viewModel.showAddZoneDialog = true }) {
                        Label("Add Zone", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }

                    Button(action: { viewModel.selectedTab = .map }) {
                        Label("Map", systemImage: "map")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.teal)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }

                // Zones List
                if viewModel.zones.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)

                        Text("No Zones")
                            .font(.headline)
                            .foregroundColor(.gray)

                        Text("Tap 'Add Zone' to create your first geofence")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    List {
                        ForEach(viewModel.zones) { zone in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(zone.name)
                                    .font(.headline)

                                HStack(spacing: 16) {
                                    Label("\(String(format: "%.4f", zone.latitude))", systemImage: "location")
                                        .font(.caption)
                                        .foregroundColor(.gray)

                                    Label("\(String(format: "%.0f", zone.radius))m", systemImage: "circlebadge")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteZone)
                    }
                    .listStyle(.insetGrouped)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("PlaceAlertMe")
        }
        .sheet(isPresented: $viewModel.showAddZoneDialog) {
            AddZoneDialog(
                latitude: $manualLatitude,
                longitude: $manualLongitude,
                radius: $manualRadius,
                onAdd: addZoneManually,
                isPresented: $viewModel.showAddZoneDialog
            )
        }
    }

    private func addZoneManually() {
        guard let lat = Double(manualLatitude),
              let lon = Double(manualLongitude),
              let rad = Double(manualRadius) else {
            return
        }

        viewModel.addZone(latitude: lat, longitude: lon, radius: rad)
        manualLatitude = ""
        manualLongitude = ""
        manualRadius = ""
        viewModel.showAddZoneDialog = false
    }

    private func deleteZone(at offsets: IndexSet) {
        for index in offsets {
            let zone = viewModel.zones[index]
            viewModel.removeZone(id: zone.id)
        }
    }
}

struct AddZoneDialog: View {
    @Binding var latitude: String
    @Binding var longitude: String
    @Binding var radius: String
    var onAdd: () -> Void
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Form {
                    Section("Location") {
                        TextField("Latitude", text: $latitude)
                            .keyboardType(.decimalPad)

                        TextField("Longitude", text: $longitude)
                            .keyboardType(.decimalPad)
                    }

                    Section("Zone") {
                        TextField("Radius (meters)", text: $radius)
                            .keyboardType(.numberPad)
                    }

                    Section {
                        Button(action: {
                            onAdd()
                        }) {
                            HStack {
                                Spacer()
                                Text("Create Zone")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(.white)
                        }
                        .listRowBackground(Color.purple)
                    }
                }
            }
            .navigationTitle("Add Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    HomeScreen()
        .environmentObject(AppViewModel())
}
