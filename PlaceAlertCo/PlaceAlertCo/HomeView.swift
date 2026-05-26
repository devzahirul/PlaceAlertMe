import SwiftUI

struct HomeView: View {
    @StateObject private var store = AlertStore.shared
    @State private var showingAddPlace = false
    @Environment(\.colorScheme) var colorScheme

    var accentColor: Color = RounderTheme.accents[0].color

    var bgColor: Color { colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight }
    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if store.alerts.isEmpty {
                EmptyStateView(action: { showingAddPlace = true }, accentColor: accentColor)
            } else {
                HomeListView(store: store, showingAddPlace: $showingAddPlace, accentColor: accentColor)
            }

            // FAB
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    FloatingActionButton(action: { showingAddPlace = true })
                        .padding(24)
                }
            }
        }
        .navigationTitle("Your places")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                MonoLabel(text: "ROUNDER")
            }

            if !store.alerts.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    LiveBadge(count: store.activeAlertsCount, isLive: store.isTracking)
                }
            }
        }
        .fullScreenCover(isPresented: $showingAddPlace) {
            AddPlaceView(isPresented: $showingAddPlace, accentColor: accentColor)
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let action: () -> Void
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme

    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Illustration
            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .foregroundColor(textColor)
                    .opacity(0.5)

                Circle()
                    .fill(accentColor)
                    .frame(width: 16, height: 16)
            }
            .frame(width: 200, height: 200)

            // Message
            VStack(spacing: 12) {
                Text("Pin a location")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(textColor)

                Text("Set a geofence and get reminded when you arrive at or leave a place.")
                    .font(.system(size: 14))
                    .foregroundColor(mutedColor)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            // CTA
            OutlineBtn(
                label: "Pin first place",
                action: action,
                primary: true,
                accent: accentColor,
                size: .lg,
                full: true
            )
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Home List View
struct HomeListView: View {
    @ObservedObject var store: AlertStore
    @Binding var showingAddPlace: Bool
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color { colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight }
    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }

    var body: some View {
        VStack(spacing: 0) {
            Text("\(store.alerts.count) reminder\(store.alerts.count == 1 ? "" : "s")")
                .font(.system(size: 15))
                .foregroundColor(mutedColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 14)

            // Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(label: "All", isSelected: true) {}
                    FilterChip(label: "Arriving", isSelected: false) {}
                    FilterChip(label: "Leaving", isSelected: false) {}
                    FilterChip(label: "Paused", isSelected: false) {}
                }
                .padding(.horizontal, 24)
            }

            // Alerts List
            ScrollView {
                VStack(spacing: 12) {
                    // Nearest active zone (only when we have a location + active alerts)
                    if let nearest = store.nearestActiveAlert {
                        NavigationLink(destination: DetailView(alert: nearest.alert, accentColor: accentColor)) {
                            NearestZoneCard(
                                alert: nearest.alert,
                                distanceMeters: nearest.distanceMeters,
                                accentColor: accentColor
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                    }

                    ForEach(store.alerts) { alert in
                        AlertCardView(alert: alert, accentColor: accentColor)
                    }

                    // Add Place Button
                    Button(action: { showingAddPlace = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 24))

                            Text("Pin a new place")
                                .font(.system(size: 14))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .foregroundColor(mutedColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                .foregroundColor(mutedColor)
                        )
                    }
                    .padding(24)
                }
                .padding(.top, 12)
                .padding(.bottom, 100)
            }

            Spacer()
        }
        .background(bgColor)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var borderColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var bgColor: Color { colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : borderColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? borderColor : bgColor, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: 1.25)
                )
        }
    }
}

// MARK: - Alert Card
struct AlertCardView: View {
    let alert: Alert
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var store = AlertStore.shared

    var borderColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var bgColor: Color { colorScheme == .dark ? RounderTheme.surfaceDark : RounderTheme.surfaceLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }

    /// Two-way binding into the store. Reading returns the current
    /// `isActive` state; writing dispatches a toggle. Without this (the old
    /// code used `.constant(alert.isActive)`) the OutlineToggle's
    /// `isOn.toggle()` was a no-op against a read-only binding.
    private var isActiveBinding: Binding<Bool> {
        Binding(
            get: { alert.isActive },
            set: { _ in store.toggleAlertActive(id: alert.id) }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            // Navigation area — wrapping ONLY the non-toggle content so
            // tapping the toggle doesn't also navigate to detail.
            NavigationLink(destination: DetailView(alert: alert, accentColor: accentColor)) {
                HStack(spacing: 12) {
                    OutlineMapThumbnail(
                        latitude: alert.latitude,
                        longitude: alert.longitude,
                        accent: accentColor
                    )
                    .frame(width: 110, height: 110)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: alert.trigger == .arriving ? "arrow.up.right" : "arrow.down.left")
                                .font(.system(size: 10, weight: .semibold))

                            Text("\(alert.trigger.rawValue) · \(Int(alert.radiusMeters))M")
                                .font(.system(size: 10).monospaced())
                                .textCase(.uppercase)

                            Spacer()
                        }
                        .foregroundColor(mutedColor)

                        Text(alert.task)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        Text(alert.place)
                            .font(.system(size: 13))
                            .foregroundColor(mutedColor)
                            .lineLimit(1)

                        Spacer(minLength: 0)
                    }
                    .frame(maxHeight: 110, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            // Toggle — sibling of the NavigationLink so its tap doesn't
            // bubble up as a navigation. Real binding writes back through
            // the store.
            OutlineToggle(isOn: isActiveBinding, accentColor: accentColor)
                .opacity(alert.isActive ? 1.0 : 0.85)
        }
        .padding(12)
        .background(bgColor, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: 1.25)
        )
        .padding(.horizontal, 24)
    }
}

// MARK: - Nearest Zone Card
struct NearestZoneCard: View {
    let alert: Alert
    let distanceMeters: Double
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme
    @State private var pulse = false

    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }
    var bgColor: Color { colorScheme == .dark ? RounderTheme.surfaceDark : RounderTheme.surfaceLight }

    var isInsideZone: Bool { distanceMeters <= alert.radiusMeters }

    var statusText: String {
        isInsideZone ? "INSIDE ZONE" : "NEAREST"
    }

    var statusColor: Color {
        isInsideZone ? RounderTheme.success : accentColor
    }

    var body: some View {
        HStack(spacing: 14) {
            // Pulsing indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.3))
                    .frame(width: 28, height: 28)
                    .scaleEffect(pulse ? 1.5 : 1.0)
                    .opacity(pulse ? 0 : 1)
                    .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)

                Circle()
                    .fill(statusColor)
                    .frame(width: 14, height: 14)

                Image(systemName: alert.icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(statusText)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(statusColor)

                Text(alert.place)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)

                Text(alert.task)
                    .font(.system(size: 12))
                    .foregroundColor(mutedColor)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(AlertStore.formatDistance(distanceMeters))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(textColor)
                Text("away")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundColor(mutedColor)
            }
        }
        .padding(16)
        .background(bgColor, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(statusColor.opacity(0.4), lineWidth: 1.5)
        )
        .onAppear { pulse = true }
    }
}

#Preview {
    HomeView()
}
