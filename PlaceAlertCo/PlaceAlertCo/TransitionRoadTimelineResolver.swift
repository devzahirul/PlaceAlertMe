import Foundation
import CoreLocation
import PlaceAlertMe

struct TransitionRoadTimelineItem: Identifiable {
    let id: String
    let roadName: String
    let startTimestampMs: Int64
    let endTimestampMs: Int64

    var startDate: Date {
        Date(timeIntervalSince1970: TimeInterval(startTimestampMs) / 1000.0)
    }

    var endDate: Date {
        Date(timeIntervalSince1970: TimeInterval(endTimestampMs) / 1000.0)
    }

    var timeText: String {
        let startText = startDate.formatted(date: .omitted, time: .shortened)
        let endText = endDate.formatted(date: .omitted, time: .shortened)
        return startText == endText ? startText : "\(startText) - \(endText)"
    }
}

protocol TransitionRoadNameResolving {
    func roadName(for coordinate: CLLocationCoordinate2D) async -> String?
}

final class TransitionRoadTimelineResolver {
    static let shared = TransitionRoadTimelineResolver()

    private let roadNameResolver: TransitionRoadNameResolving
    private let maxSampleCount: Int
    private var cache: [String: [TransitionRoadTimelineItem]] = [:]

    init(
        roadNameResolver: TransitionRoadNameResolving = MapKitTransitionRoadNameResolver(),
        maxSampleCount: Int = 32
    ) {
        self.roadNameResolver = roadNameResolver
        self.maxSampleCount = max(2, maxSampleCount)
    }

    func timeline(for day: NavigationHistoryDay) async -> [TransitionRoadTimelineItem] {
        let points = day.points.sorted { $0.timestampMs < $1.timestampMs }
        guard !points.isEmpty else { return [] }

        let key = cacheKey(dayKey: day.dayKey, points: points)
        if let cached = cache[key] {
            return cached
        }

        let samples = sampledPoints(from: points)
        var namedPoints: [(point: NavigationHistoryRoutePoint, roadName: String)] = []
        namedPoints.reserveCapacity(samples.count)

        for point in samples {
            if Task.isCancelled {
                return []
            }
            guard let roadName = await roadNameResolver.roadName(for: point.coordinate) else {
                continue
            }
            namedPoints.append((point, roadName))
        }

        let items = collapsedItems(from: namedPoints)
        cache[key] = items
        return items
    }

    private func sampledPoints(from points: [NavigationHistoryRoutePoint]) -> [NavigationHistoryRoutePoint] {
        guard points.count > maxSampleCount else { return points }

        let lastIndex = points.count - 1
        var result: [NavigationHistoryRoutePoint] = []
        result.reserveCapacity(maxSampleCount)

        for step in 0..<maxSampleCount {
            let exactIndex = Double(step) * Double(lastIndex) / Double(maxSampleCount - 1)
            let index = Int(exactIndex.rounded())
            if result.last?.timestampMs != points[index].timestampMs {
                result.append(points[index])
            }
        }
        return result
    }

    private func collapsedItems(
        from namedPoints: [(point: NavigationHistoryRoutePoint, roadName: String)]
    ) -> [TransitionRoadTimelineItem] {
        guard let first = namedPoints.first else { return [] }

        var items: [TransitionRoadTimelineItem] = []
        var currentName = first.roadName
        var currentStart = first.point.timestampMs
        var currentEnd = first.point.timestampMs

        for entry in namedPoints.dropFirst() {
            if namesMatch(currentName, entry.roadName) {
                currentEnd = entry.point.timestampMs
            } else {
                currentEnd = entry.point.timestampMs
                items.append(item(roadName: currentName, start: currentStart, end: currentEnd))
                currentName = entry.roadName
                currentStart = entry.point.timestampMs
                currentEnd = entry.point.timestampMs
            }
        }

        items.append(item(roadName: currentName, start: currentStart, end: currentEnd))
        return items
    }

    private func item(roadName: String, start: Int64, end: Int64) -> TransitionRoadTimelineItem {
        TransitionRoadTimelineItem(
            id: "\(start)-\(end)-\(roadName)",
            roadName: roadName,
            startTimestampMs: start,
            endTimestampMs: max(start, end)
        )
    }

    private func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private func cacheKey(dayKey: String, points: [NavigationHistoryRoutePoint]) -> String {
        let fingerprint = points
            .map { "\($0.timestampMs):\(String(format: "%.5f,%.5f", $0.latitude, $0.longitude))" }
            .joined(separator: "|")
        return "\(dayKey)|\(maxSampleCount)|\(fingerprint)"
    }
}

final class MapKitTransitionRoadNameResolver: TransitionRoadNameResolving {
    private let geocoder = CLGeocoder()
    private var cache: [String: String] = [:]
    private var misses: Set<String> = []

    func roadName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let key = cacheKey(for: coordinate)
        if let cached = cache[key] {
            return cached
        }
        if misses.contains(key) {
            return nil
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = (try? await geocoder.reverseGeocodeLocation(location)) ?? []
        guard let roadName = placemarks.compactMap(Self.roadName(from:)).first else {
            misses.insert(key)
            return nil
        }

        cache[key] = roadName
        return roadName
    }

    private static func roadName(from placemark: CLPlacemark) -> String? {
        let candidates = [
            placemark.thoroughfare,
            placemark.name,
        ]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func cacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
    }
}

private extension NavigationHistoryRoutePoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
