import SwiftUI
import MapKit

struct MapScreen: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var radius: Double = 500
    @State private var mapSelection: CLLocationCoordinate2D?

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position, selection: $mapSelection) {
                    if let selectedLocation = selectedLocation {
                        Annotation("Selected", coordinate: selectedLocation) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.3))
                                    .frame(width: radius * 0.00001, height: radius * 0.00001)

                                Circle()
                                    .stroke(Color.purple, lineWidth: 2)
                                    .frame(width: 30, height: 30)

                                Image(systemName: "location.fill")
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                }
                .mapStyle(.standard)
                .onTapGesture { position in
                    if let coordinate = position.coordinate {
                        selectedLocation = coordinate
                    }
                }

                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            if let location = selectedLocation {
                                Text("Selected Location")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(format: "Lat: %.4f", location.latitude))
                                        .font(.caption)
                                        .foregroundColor(.white)

                                    Text(String(format: "Lon: %.4f", location.longitude))
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            } else {
                                Text("Tap map to select location")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)

                        Spacer()
                    }
                    .padding()

                    Spacer()

                    VStack(spacing: 16) {
                        if selectedLocation != nil {
                            VStack(spacing: 12) {
                                Text("Radius: \(String(format: "%.0f", radius))m")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Slider(value: $radius, in: 100...5000, step: 100)
                                    .tint(.purple)
                            }
                            .padding()
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(8)

                            Button(action: confirmZone) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Confirm Zone")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func confirmZone() {
        guard let location = selectedLocation else { return }
        viewModel.addZone(
            latitude: location.latitude,
            longitude: location.longitude,
            radius: radius
        )
        selectedLocation = nil
        radius = 500
        viewModel.selectedTab = .home
    }
}

#Preview {
    MapScreen()
        .environmentObject(AppViewModel())
}
