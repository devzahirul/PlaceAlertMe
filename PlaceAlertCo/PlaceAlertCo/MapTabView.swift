import SwiftUI
import MapKit

struct MapTabView: View {
    @StateObject private var store = AlertStore.shared
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedAlertID: UUID?
    @Environment(\.colorScheme) var colorScheme

    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var bgColor: Color { colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight }

    var body: some View {
        ZStack {
            Map(position: $position) {
                ForEach(store.alerts) { alert in
                    MapCircle(
                        center: CLLocationCoordinate2D(latitude: alert.latitude, longitude: alert.longitude),
                        radius: alert.radiusMeters
                    )
                    .foregroundStyle(RounderTheme.accents[0].color.opacity(0.16))
                    .stroke(RounderTheme.accents[0].color.opacity(0.75), lineWidth: 2)

                    Annotation("", coordinate: CLLocationCoordinate2D(latitude: alert.latitude, longitude: alert.longitude)) {
                        Circle()
                            .fill(RounderTheme.accents[0].color)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(RounderTheme.accents[0].color.opacity(0.5), lineWidth: 6))
                    }
                }
            }
            .mapStyle(.standard)

            VStack {
                // Search Bar
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(textColor)

                    TextField("Search places", text: .constant(""))
                        .font(.system(size: 15))

                    Button(action: {}) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(RounderTheme.accents[0].color)
                    }
                }
                .padding(12)
                .background(colorScheme == .dark ? RounderTheme.surfaceDark : RounderTheme.surfaceLight)
                .cornerRadius(24)
                .padding(24)

                Spacer()

                // Bottom Sheet
                VStack(alignment: .leading, spacing: 12) {
                    Capsule()
                        .fill(textColor.opacity(0.2))
                        .frame(width: 40, height: 4)

                    Text("Nearby")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(textColor)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(store.alerts) { alert in
                                VStack(alignment: .leading, spacing: 6) {
                                    Image(systemName: alert.icon)
                                        .font(.system(size: 14))
                                        .foregroundColor(RounderTheme.accents[0].color)

                                    Text(alert.task)
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(2)

                                    Text(alert.place)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 168)
                                .padding(12)
                                .background(colorScheme == .dark ? RounderTheme.surface2Dark : RounderTheme.surface2Light)
                                .cornerRadius(12)
                                .id(alert.id)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $selectedAlertID)
                    .onChange(of: selectedAlertID) { _, newValue in
                        guard let newValue,
                              let alert = store.alerts.first(where: { $0.id == newValue }) else { return }
                        focusMap(on: alert)
                    }
                    .onChange(of: store.alerts.map(\.id)) { _, alertIDs in
                        guard let firstAlert = store.alerts.first else {
                            selectedAlertID = nil
                            return
                        }

                        guard let selectedAlertID, alertIDs.contains(selectedAlertID) else {
                            selectedAlertID = firstAlert.id
                            focusMap(on: firstAlert)
                            return
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(colorScheme == .dark ? RounderTheme.surfaceDark : RounderTheme.surfaceLight)
                .cornerRadius(24)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            guard selectedAlertID == nil, let firstAlert = store.alerts.first else { return }
            selectedAlertID = firstAlert.id
            focusMap(on: firstAlert)
        }
    }

    private func focusMap(on alert: Alert) {
        let coordinate = CLLocationCoordinate2D(latitude: alert.latitude, longitude: alert.longitude)
        let visibleMeters = max(alert.radiusMeters * 4, 800)
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: visibleMeters,
            longitudinalMeters: visibleMeters
        )

        withAnimation(.easeInOut(duration: 0.35)) {
            position = .region(region)
        }
    }
}

#Preview {
    MapTabView()
}
