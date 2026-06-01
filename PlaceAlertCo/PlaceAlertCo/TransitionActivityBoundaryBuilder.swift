import Foundation
import CoreLocation
import PlaceAlertMe

struct TransitionActivityBoundary: Identifiable {
    let id: String
    let title: String
    let timeText: String
    let coordinate: CLLocationCoordinate2D
    let role: TransitionActivityBoundaryRole

    var accessibilityLabel: String {
        "\(title) \(timeText)"
    }
}

enum TransitionActivityBoundaryRole: Equatable {
    case start
    case end
}

enum TransitionActivityBoundaryBuilder {
    static func boundaries(for day: NavigationHistoryDay) -> [TransitionActivityBoundary] {
        let points = day.points.sorted { $0.timestampMs < $1.timestampMs }
        let events = collapsedActivityEvents(for: day)
        guard let firstPoint = points.first,
              let lastPoint = points.last,
              !events.isEmpty else { return [] }

        var boundaries: [TransitionActivityBoundary] = []
        for index in events.indices {
            let event = events[index]
            let rawEndTimestamp = index + 1 < events.count
                ? events[index + 1].timestampMs
                : lastPoint.timestampMs
            let startTimestamp = min(max(event.timestampMs, firstPoint.timestampMs), lastPoint.timestampMs)
            let endTimestamp = min(max(rawEndTimestamp, firstPoint.timestampMs), lastPoint.timestampMs)
            guard endTimestamp >= startTimestamp else { continue }

            let activityTitle = title(for: event.activityType)
            let startDate = Date(timeIntervalSince1970: TimeInterval(startTimestamp) / 1000.0)
            let endDate = Date(timeIntervalSince1970: TimeInterval(endTimestamp) / 1000.0)

            boundaries.append(TransitionActivityBoundary(
                id: "\(event.id)-start",
                title: "\(activityTitle) start",
                timeText: startDate.formatted(date: .omitted, time: .shortened),
                coordinate: nearestPoint(in: points, to: startTimestamp).coordinate,
                role: .start
            ))
            boundaries.append(TransitionActivityBoundary(
                id: "\(event.id)-end",
                title: "\(activityTitle) end",
                timeText: endDate.formatted(date: .omitted, time: .shortened),
                coordinate: nearestPoint(in: points, to: endTimestamp).coordinate,
                role: .end
            ))
        }
        return boundaries
    }

    private static func collapsedActivityEvents(for day: NavigationHistoryDay) -> [NavigationHistoryActivityEvent] {
        day.activityEvents
            .sorted { $0.timestampMs < $1.timestampMs }
            .reduce(into: [NavigationHistoryActivityEvent]()) { result, event in
                if result.last?.activityType != event.activityType {
                    result.append(event)
                }
            }
    }

    private static func nearestPoint(
        in points: [NavigationHistoryRoutePoint],
        to timestampMs: Int64
    ) -> NavigationHistoryRoutePoint {
        points.min {
            abs($0.timestampMs - timestampMs) < abs($1.timestampMs - timestampMs)
        } ?? points[0]
    }

    private static func title(for rawValue: String) -> String {
        switch rawValue {
        case "stationary":
            return "Stationary"
        case "walking":
            return "Walking"
        case "running":
            return "Running"
        case "cycling":
            return "Cycling"
        case "automotive":
            return "Automotive"
        default:
            return "Unknown"
        }
    }
}

private extension NavigationHistoryRoutePoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
