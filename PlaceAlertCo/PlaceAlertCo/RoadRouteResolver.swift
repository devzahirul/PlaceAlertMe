import Foundation
import CoreLocation
import MapKit

protocol RoadRouteRouting {
    func routeCoordinates(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> [CLLocationCoordinate2D]
}

final class RoadRouteResolver {
    static let shared = RoadRouteResolver()

    private let router: RoadRouteRouting
    private let maxSegmentCount: Int
    private var cache: [String: [CLLocationCoordinate2D]] = [:]

    init(router: RoadRouteRouting = MapKitRoadRouteRouter(), maxSegmentCount: Int = 80) {
        self.router = router
        self.maxSegmentCount = max(1, maxSegmentCount)
    }

    func roadCoordinates(
        dayKey: String,
        rawCoordinates: [CLLocationCoordinate2D]
    ) async -> [CLLocationCoordinate2D] {
        guard rawCoordinates.count > 1 else { return rawCoordinates }

        let key = cacheKey(dayKey: dayKey, coordinates: rawCoordinates)
        if let cached = cache[key] {
            return cached
        }

        let anchors = routeAnchors(from: rawCoordinates)
        var resolved: [CLLocationCoordinate2D] = []
        var foundRoadSegment = false

        for index in 0..<(anchors.count - 1) {
            if Task.isCancelled {
                return rawCoordinates
            }

            let source = anchors[index]
            let destination = anchors[index + 1]
            let segment: [CLLocationCoordinate2D]

            do {
                let routed = try await router.routeCoordinates(from: source, to: destination)
                if routed.count > 1 {
                    segment = routed
                    foundRoadSegment = true
                } else {
                    segment = [source, destination]
                }
            } catch {
                segment = [source, destination]
            }

            append(segment, to: &resolved)
        }

        guard foundRoadSegment else { return rawCoordinates }
        cache[key] = resolved
        return resolved
    }

    private func routeAnchors(from coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxSegmentCount + 1 else { return coordinates }

        let lastIndex = coordinates.count - 1
        var anchors: [CLLocationCoordinate2D] = []
        anchors.reserveCapacity(maxSegmentCount + 1)

        for step in 0...maxSegmentCount {
            let exactIndex = Double(step) * Double(lastIndex) / Double(maxSegmentCount)
            let index = Int(exactIndex.rounded())
            if anchors.last.map({ coordinatesMatch($0, coordinates[index]) }) != true {
                anchors.append(coordinates[index])
            }
        }

        if anchors.last.map({ coordinatesMatch($0, coordinates[lastIndex]) }) != true {
            anchors.append(coordinates[lastIndex])
        }

        return anchors
    }

    private func append(_ segment: [CLLocationCoordinate2D], to resolved: inout [CLLocationCoordinate2D]) {
        guard !segment.isEmpty else { return }

        if let last = resolved.last,
           let first = segment.first,
           coordinatesMatch(last, first) {
            resolved.append(contentsOf: segment.dropFirst())
        } else {
            resolved.append(contentsOf: segment)
        }
    }

    private func cacheKey(dayKey: String, coordinates: [CLLocationCoordinate2D]) -> String {
        let fingerprint = coordinates
            .map {
                String(
                    format: "%.6f,%.6f",
                    locale: Locale(identifier: "en_US_POSIX"),
                    $0.latitude,
                    $0.longitude
                )
            }
            .joined(separator: ";")
        return "\(maxSegmentCount)|\(dayKey)|\(fingerprint)"
    }
}

struct MapKitRoadRouteRouter: RoadRouteRouting {
    func routeCoordinates(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async throws -> [CLLocationCoordinate2D] {
        let request = MKDirections.Request()
        request.source = mapItem(for: source)
        request.destination = mapItem(for: destination)
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        let response: MKDirections.Response = try await withCheckedThrowingContinuation { continuation in
            directions.calculate { response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let response else {
                    continuation.resume(throwing: RoadRouteError.noRoute)
                    return
                }

                continuation.resume(returning: response)
            }
        }

        guard let route = response.routes.first else {
            throw RoadRouteError.noRoute
        }

        return route.polyline.routeCoordinates
    }

    private func mapItem(for coordinate: CLLocationCoordinate2D) -> MKMapItem {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return MKMapItem(location: location, address: nil)
    }
}

private enum RoadRouteError: Error {
    case noRoute
}

private extension MKPolyline {
    var routeCoordinates: [CLLocationCoordinate2D] {
        guard pointCount > 0 else { return [] }

        var coordinates = Array(
            repeating: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            count: pointCount
        )
        getCoordinates(&coordinates, range: NSRange(location: 0, length: pointCount))
        return coordinates
    }
}

private func coordinatesMatch(
    _ lhs: CLLocationCoordinate2D,
    _ rhs: CLLocationCoordinate2D
) -> Bool {
    abs(lhs.latitude - rhs.latitude) < 0.000001 &&
        abs(lhs.longitude - rhs.longitude) < 0.000001
}
