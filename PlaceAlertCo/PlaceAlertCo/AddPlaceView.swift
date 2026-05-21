import SwiftUI
import MapKit
import CoreLocation

struct AddPlaceView: View {
    @Binding var isPresented: Bool
    @State private var step: AddStep = .pick
    @State private var selectedPlace: (name: String, lat: Double, lon: Double, addr: String)?
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme

    enum AddStep {
        case pick
        case configure
    }

    var bgColor: Color { colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight }

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()

                switch step {
                case .pick:
                    MapPickerStepView(
                        onSelectPlace: { place in
                            selectedPlace = place
                            step = .configure
                        },
                        accentColor: accentColor
                    )

                case .configure:
                    if let place = selectedPlace {
                        ConfigureStepView(
                            place: place,
                            onBack: { step = .pick },
                            onDismiss: { isPresented = false },
                            accentColor: accentColor
                        )
                    }
                }
            }
            .navigationTitle(step == .pick ? "Pin a place" : "New reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if step == .pick {
                            isPresented = false
                        } else {
                            step = .pick
                        }
                    } label: {
                        Image(systemName: step == .pick ? "xmark" : "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight)
                }
            }
        }
    }
}

// MARK: - Map Picker Step
struct MapPickerStepView: View {
    let onSelectPlace: ((name: String, lat: Double, lon: Double, addr: String)) -> Void
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme

    // Default fallback if user location unavailable
    private static let fallbackCenter = CLLocationCoordinate2D(latitude: 23.78, longitude: 90.41)
    private static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(center: fallbackCenter, span: defaultSpan)
    )
    @State private var pinnedCoordinate: CLLocationCoordinate2D = fallbackCenter
    @State private var currentRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: fallbackCenter, span: defaultSpan
    )
    @State private var addressText: String = "Locating…"
    @State private var placeName: String = ""
    @State private var searchText: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var geocodeTask: Task<Void, Never>?
    @State private var searchTask: Task<Void, Never>?
    @State private var didInitialize = false

    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }
    var surfaceColor: Color { colorScheme == .dark ? RounderTheme.surfaceDark : RounderTheme.surfaceLight }
    var surface2Color: Color { colorScheme == .dark ? RounderTheme.surface2Dark : RounderTheme.surface2Light }

    var isLocating: Bool { addressText == "Locating…" }

    var body: some View {
        ZStack {
            // Full-screen map underneath everything
            Map(position: $cameraPosition)
                .mapStyle(.standard)
                .ignoresSafeArea(edges: .bottom)
                .onMapCameraChange(frequency: .continuous) { context in
                    pinnedCoordinate = context.camera.centerCoordinate
                    currentRegion = context.region
                    scheduleGeocode(for: context.camera.centerCoordinate)
                }

            // Screen-fixed center pin — sits at ZStack visual center.
            // Offset so the pin's tip lands exactly on the map center, not its midpoint.
            Image(systemName: "mappin")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(accentColor)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                .offset(y: -20)
                .allowsHitTesting(false)

            // Top: search bar + dropdown of results
            VStack(spacing: 0) {
                searchBar
                if !searchResults.isEmpty {
                    searchResultsDropdown
                }
                Spacer()
            }

            // Bottom: address card + CTA
            VStack {
                Spacer()
                bottomCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .onAppear {
            initializeMapIfNeeded()
        }
        .onChange(of: searchText) { _, newValue in
            scheduleSearch(query: newValue)
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(mutedColor)

            TextField("Search a place or address", text: $searchText)
                .font(.system(size: 15))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(mutedColor)
                }
            }
        }
        .padding(12)
        .background(surface2Color, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(textColor.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var searchResultsDropdown: some View {
        let visible = Array(searchResults.prefix(6))
        return VStack(spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.offset) { index, item in
                Button(action: { selectSearchResult(item) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name ?? "Unknown")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(textColor)
                            .lineLimit(1)
                        Text(formatPlacemark(item.placemark))
                            .font(.system(size: 13))
                            .foregroundColor(mutedColor)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                }
                if index < visible.count - 1 {
                    Divider().padding(.leading, 14)
                }
            }
        }
        .background(surfaceColor, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(textColor.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Bottom Card
    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(placeName.isEmpty ? "Pinned Location" : placeName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                Text(addressText)
                    .font(.system(size: 13))
                    .foregroundColor(mutedColor)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            OutlineBtn(
                label: "Use this location",
                action: {
                    let resolvedName = placeName.isEmpty ? "Pinned Location" : placeName
                    onSelectPlace((resolvedName, pinnedCoordinate.latitude, pinnedCoordinate.longitude, addressText))
                },
                primary: true,
                accent: accentColor,
                size: .lg,
                full: true
            )
            .opacity(isLocating ? 0.5 : 1)
            .disabled(isLocating)
        }
        .padding(16)
        .background(surfaceColor, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(textColor.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    }

    // MARK: - Initialization
    private func initializeMapIfNeeded() {
        guard !didInitialize else { return }
        didInitialize = true

        let manager = CLLocationManager()
        let coordinate = manager.location?.coordinate ?? Self.fallbackCenter
        let region = MKCoordinateRegion(center: coordinate, span: Self.defaultSpan)

        cameraPosition = .region(region)
        pinnedCoordinate = coordinate
        currentRegion = region
        scheduleGeocode(for: coordinate)
    }

    // MARK: - Reverse Geocoding (debounced)
    private func scheduleGeocode(for coord: CLLocationCoordinate2D) {
        geocodeTask?.cancel()
        addressText = "Locating…"
        geocodeTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            if Task.isCancelled { return }
            await reverseGeocode(coord)
        }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let placemarks = (try? await geocoder.reverseGeocodeLocation(location)) ?? []

        guard !Task.isCancelled else { return }

        guard let placemark = placemarks.first else {
            await MainActor.run {
                placeName = "Pinned Location"
                addressText = String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
            }
            return
        }

        let name = placemark.name ?? placemark.thoroughfare ?? "Pinned Location"
        let parts = [placemark.subLocality, placemark.locality, placemark.administrativeArea].compactMap { $0 }
        let addr = parts.joined(separator: ", ")
        let resolvedAddr = addr.isEmpty ? (placemark.country ?? "Unknown area") : addr

        await MainActor.run {
            placeName = name
            addressText = resolvedAddr
        }
    }

    // MARK: - Local Search (debounced)
    private func scheduleSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s debounce
            if Task.isCancelled { return }
            await runLocalSearch(trimmed, in: currentRegion)
        }
    }

    private func runLocalSearch(_ query: String, in region: MKCoordinateRegion) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region

        let response = try? await MKLocalSearch(request: request).start()
        guard !Task.isCancelled else { return }

        await MainActor.run {
            searchResults = response?.mapItems ?? []
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        withAnimation(.easeInOut(duration: 0.4)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
            ))
        }
        searchText = item.name ?? ""
        searchResults = []
        // Geocode will run via onMapCameraChange callback
    }

    private func formatPlacemark(_ placemark: MKPlacemark) -> String {
        let parts = [placemark.thoroughfare, placemark.locality, placemark.administrativeArea].compactMap { $0 }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Configure Step
struct ConfigureStepView: View {
    let place: (name: String, lat: Double, lon: Double, addr: String)
    let onBack: () -> Void
    let onDismiss: () -> Void
    let accentColor: Color

    @State private var task = ""
    @State private var trigger: Alert.Trigger = .arriving
    @State private var radiusMeters: Double = 500
    @State private var selectedIcon = "mappin"

    @StateObject private var store = AlertStore.shared
    @Environment(\.colorScheme) var colorScheme

    let radiusOptions: [(label: String, value: Double)] = [
        ("100M", 100),
        ("250M", 250),
        ("500M", 500),
        ("1 KM", 1000),
    ]

    let icons = ["cart", "cup.and.saucer", "box.2", "book", "briefcase", "house", "figure.walk", "cross.case", "mappin"]

    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }
    var bgColor: Color { colorScheme == .dark ? RounderTheme.surfaceDark : RounderTheme.surfaceLight }

    var body: some View {
        VStack(spacing: 0) {
            // Map Preview
            OutlineMapThumbnail(
                latitude: place.lat,
                longitude: place.lon,
                accent: accentColor
            )
            .frame(height: 200)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Form
            ScrollView {
                VStack(spacing: 24) {
                    // Task Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REMIND ME TO")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(mutedColor)

                        TextField("Add task description", text: $task)
                            .font(.system(size: 17, weight: .semibold))
                            .padding(12)
                            .background(bgColor)
                            .cornerRadius(8)
                    }

                    // Trigger
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TRIGGER")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(mutedColor)

                        Picker("Trigger", selection: $trigger) {
                            Text("Arriving").tag(Alert.Trigger.arriving)
                            Text("Leaving").tag(Alert.Trigger.leaving)
                            Text("Both").tag(Alert.Trigger.both)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Radius
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RADIUS")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(mutedColor)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(radiusOptions, id: \.value) { opt in
                                    Button(action: { radiusMeters = opt.value }) {
                                        Text(opt.label)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(radiusMeters == opt.value ? .white : textColor)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(radiusMeters == opt.value ? textColor : bgColor, in: Capsule())
                                            .overlay(
                                                Capsule()
                                                    .stroke(textColor, lineWidth: 1.25)
                                            )
                                    }
                                }
                            }
                        }

                        Slider(value: $radiusMeters, in: 50...1500, step: 50)
                            .tint(accentColor)

                        Text("\(Int(radiusMeters))m")
                            .font(.system(size: 13))
                            .foregroundColor(mutedColor)
                    }

                    // Icon Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ICON")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(mutedColor)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .foregroundColor(selectedIcon == icon ? .white : textColor)
                                        .background(selectedIcon == icon ? textColor : bgColor, in: RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(textColor, lineWidth: selectedIcon == icon ? 2 : 1.25)
                                        )
                                }
                            }
                        }
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            // Footer Buttons
            VStack(spacing: 12) {
                OutlineBtn(
                    label: "Pin place",
                    action: {
                        let alert = Alert(
                            task: task,
                            place: place.name,
                            address: place.addr,
                            latitude: place.lat,
                            longitude: place.lon,
                            radiusMeters: radiusMeters,
                            trigger: trigger,
                            icon: selectedIcon
                        )
                        store.addAlert(alert)
                        onDismiss()
                    },
                    primary: true,
                    accent: accentColor,
                    size: .lg,
                    full: true
                )

                OutlineBtn(
                    label: "Cancel",
                    action: onDismiss,
                    primary: false,
                    size: .lg,
                    full: true
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight)
    }
}

#Preview {
    AddPlaceView(isPresented: .constant(true), accentColor: RounderTheme.accents[0].color)
}
