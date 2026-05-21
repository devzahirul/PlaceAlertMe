import SwiftUI
import MapKit
import PlaceAlertMe

struct TransitionsView: View {
    @StateObject private var store = TransitionHistoryStore.shared
    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color { colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight }
    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if store.summaries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: 34))
                        .foregroundColor(mutedColor)

                    Text("No transitions yet")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(textColor)

                    Text("Daily movement history will appear after location tracking records route points.")
                        .font(.system(size: 14))
                        .foregroundColor(mutedColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(store.summaries) { summary in
                            NavigationLink(destination: TransitionDayDetailView(dayKey: summary.dayKey)) {
                                TransitionDayRow(summary: summary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationTitle("Transitions")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                MonoLabel(text: "HISTORY")
            }
        }
        .onAppear {
            store.refresh()
        }
    }
}

private struct TransitionDayRow: View {
    let summary: NavigationHistoryDaySummary
    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color { colorScheme == .dark ? RounderTheme.surfaceDark : RounderTheme.surfaceLight }
    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(dayNumber)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(textColor)

                Text(monthName)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .textCase(.uppercase)
                    .foregroundColor(mutedColor)
            }
            .frame(width: 54, height: 54)
            .background(colorScheme == .dark ? RounderTheme.surface2Dark : RounderTheme.surface2Light, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(displayDate)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(textColor)

                Text(timeRange)
                    .font(.system(size: 13))
                    .foregroundColor(mutedColor)

                HStack(spacing: 10) {
                    Label(AlertStore.formatDistance(summary.distanceMeters), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    Label("\(summary.alertEventCount) alert\(summary.alertEventCount == 1 ? "" : "s")", systemImage: "bell")
                    Label("\(summary.pointCount) points", systemImage: "location")
                }
                .font(.system(size: 11))
                .foregroundColor(mutedColor)
                .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(mutedColor)
        }
        .padding(16)
        .background(bgColor, in: RoundedRectangle(cornerRadius: 16))
    }

    private var date: Date? {
        Self.dayFormatter.date(from: summary.dayKey)
    }

    private var displayDate: String {
        date?.formatted(date: .abbreviated, time: .omitted) ?? summary.dayKey
    }

    private var dayNumber: String {
        guard let date else { return "--" }
        return date.formatted(.dateTime.day(.twoDigits))
    }

    private var monthName: String {
        guard let date else { return "Day" }
        return date.formatted(.dateTime.month(.abbreviated))
    }

    private var timeRange: String {
        guard let start = summary.startDate, let end = summary.endDate else {
            return "No movement recorded"
        }
        return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct TransitionDayDetailView: View {
    let dayKey: String

    @StateObject private var store = TransitionHistoryStore.shared
    @State private var day: NavigationHistoryDay?
    @State private var position: MapCameraPosition = .automatic
    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color { colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight }
    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                routeMap
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                if let day {
                    summaryGrid(day.summary)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("ALERTS")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(mutedColor)

                        if day.alertEvents.isEmpty {
                            Text("No alert triggers recorded for this day.")
                                .font(.system(size: 14))
                                .foregroundColor(mutedColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(colorScheme == .dark ? RounderTheme.surfaceDark : RounderTheme.surfaceLight, in: RoundedRectangle(cornerRadius: 16))
                        } else {
                            ForEach(day.alertEvents) { event in
                                TransitionAlertEventRow(event: event)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 90)
        }
        .background(bgColor.ignoresSafeArea())
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadDay)
    }

    @ViewBuilder
    private var routeMap: some View {
        if let day {
            Map(position: $position) {
                let coordinates = routeCoordinates(for: day)

                if coordinates.count > 1 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(RounderTheme.accents[0].color, lineWidth: 4)
                }

                if let first = coordinates.first {
                    Annotation("Start", coordinate: first) {
                        Circle()
                            .fill(RounderTheme.success)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                    }
                }

                if coordinates.count > 1, let last = coordinates.last {
                    Annotation("End", coordinate: last) {
                        Circle()
                            .fill(RounderTheme.danger)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                    }
                }

                ForEach(day.alertEvents) { event in
                    Annotation(event.place, coordinate: event.coordinate) {
                        Image(systemName: event.eventType == "Arriving" ? "bell.fill" : "bell.slash.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(RounderTheme.accents[0].color, in: Circle())
                    }
                }
            }
            .mapStyle(.standard)
        } else {
            Rectangle()
                .fill(colorScheme == .dark ? RounderTheme.surface2Dark : RounderTheme.surface2Light)
                .overlay {
                    ProgressView()
                }
        }
    }

    private func summaryGrid(_ summary: NavigationHistoryDaySummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(label: "Distance", value: AlertStore.formatDistance(summary.distanceMeters), accentColor: RounderTheme.accents[0].color)
            StatTile(label: "Alerts", value: "\(summary.alertEventCount)", accentColor: RounderTheme.warn)
            StatTile(label: "Points", value: "\(summary.pointCount)", accentColor: RounderTheme.accents[0].color)
            StatTile(label: "Time", value: shortTimeRange(summary), accentColor: mutedColor)
        }
        .padding(.horizontal, 24)
    }

    private var displayTitle: String {
        guard let date = Self.dayFormatter.date(from: dayKey) else { return dayKey }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func loadDay() {
        day = store.loadDay(dayKey: dayKey)
        if let day {
            focusMap(on: day)
        }
    }

    private func routeCoordinates(for day: NavigationHistoryDay) -> [CLLocationCoordinate2D] {
        day.points.map(\.coordinate)
    }

    private func focusMap(on day: NavigationHistoryDay) {
        var coordinates = routeCoordinates(for: day)
        coordinates.append(contentsOf: day.alertEvents.map(\.coordinate))
        guard !coordinates.isEmpty else { return }

        if coordinates.count == 1, let coordinate = coordinates.first {
            position = .region(MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 1200,
                longitudinalMeters: 1200
            ))
            return
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let minLat = latitudes.min(),
              let maxLat = latitudes.max(),
              let minLon = longitudes.min(),
              let maxLon = longitudes.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.01)
        )

        position = .region(MKCoordinateRegion(center: center, span: span))
    }

    private func shortTimeRange(_ summary: NavigationHistoryDaySummary) -> String {
        guard let start = summary.startDate, let end = summary.endDate else { return "--" }
        return "\(start.formatted(date: .omitted, time: .shortened))-\(end.formatted(date: .omitted, time: .shortened))"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct TransitionAlertEventRow: View {
    let event: NavigationHistoryAlertEvent
    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color { colorScheme == .dark ? RounderTheme.surfaceDark : RounderTheme.surfaceLight }
    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.eventType == "Arriving" ? "arrow.up.right" : "arrow.down.left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(RounderTheme.accents[0].color, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(event.task)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)
                    .lineLimit(2)

                Text("\(event.eventType) at \(event.place)")
                    .font(.system(size: 13))
                    .foregroundColor(mutedColor)

                Text(event.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(mutedColor)
            }

            Spacer()
        }
        .padding(16)
        .background(bgColor, in: RoundedRectangle(cornerRadius: 16))
    }
}

private extension NavigationHistoryRoutePoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension NavigationHistoryAlertEvent {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

#Preview {
    NavigationStack {
        TransitionsView()
    }
}
