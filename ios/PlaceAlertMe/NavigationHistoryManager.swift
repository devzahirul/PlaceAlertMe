import Foundation

#if os(iOS)
import GeoEngineWrapper

public struct NavigationHistoryRoutePoint: Codable, Hashable {
    public let timestampMs: Int64
    public let latitude: Double
    public let longitude: Double
    public let speedMps: Double

    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestampMs) / 1000.0)
    }
}

public struct NavigationHistoryAlertEvent: Codable, Hashable, Identifiable {
    public let id: String
    public let timestampMs: Int64
    public let alertId: String
    public let task: String
    public let place: String
    public let address: String
    public let eventType: String
    public let latitude: Double
    public let longitude: Double

    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestampMs) / 1000.0)
    }
}

public struct NavigationHistoryDaySummary: Codable, Hashable, Identifiable {
    public let dayKey: String
    public let startTimestampMs: Int64
    public let endTimestampMs: Int64
    public let pointCount: Int
    public let alertEventCount: Int
    public let distanceMeters: Double

    public var id: String { dayKey }

    public var startDate: Date? {
        startTimestampMs > 0 ? Date(timeIntervalSince1970: TimeInterval(startTimestampMs) / 1000.0) : nil
    }

    public var endDate: Date? {
        endTimestampMs > 0 ? Date(timeIntervalSince1970: TimeInterval(endTimestampMs) / 1000.0) : nil
    }
}

public struct NavigationHistoryDay: Codable, Hashable {
    public let dayKey: String
    public let summary: NavigationHistoryDaySummary
    public let points: [NavigationHistoryRoutePoint]
    public let alertEvents: [NavigationHistoryAlertEvent]
}

public final class NavigationHistoryManager {
    private let directoryURL: URL
    private let decoder = JSONDecoder()

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
    }

    @discardableResult
    public func appendRoutePoint(
        dayKey: String,
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        speedMps: Double = 0.0
    ) -> Bool {
        withDirectoryAndDay(dayKey) { directory, day in
            ios_navigation_history_append_route_point(
                directory,
                day,
                Self.timestampMs(for: timestamp),
                latitude,
                longitude,
                speedMps
            )
        }
    }

    @discardableResult
    public func appendAlertEvent(
        dayKey: String,
        eventId: String,
        alertId: String,
        task: String,
        place: String,
        address: String,
        eventType: String,
        timestamp: Date,
        latitude: Double,
        longitude: Double
    ) -> Bool {
        directoryURL.path.withCString { directory in
            dayKey.withCString { day in
                eventId.withCString { eventIdPointer in
                    alertId.withCString { alertIdPointer in
                        task.withCString { taskPointer in
                            place.withCString { placePointer in
                                address.withCString { addressPointer in
                                    eventType.withCString { eventTypePointer in
                                        ios_navigation_history_append_alert_event(
                                            directory,
                                            day,
                                            eventIdPointer,
                                            alertIdPointer,
                                            taskPointer,
                                            placePointer,
                                            addressPointer,
                                            eventTypePointer,
                                            Self.timestampMs(for: timestamp),
                                            latitude,
                                            longitude
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    public func listDaySummaries(limit: Int = 512) -> [NavigationHistoryDaySummary] {
        guard limit > 0 else { return [] }

        var rawSummaries = Array(repeating: NavigationHistoryDaySummaryResult(), count: limit)
        let count = directoryURL.path.withCString { directory in
            rawSummaries.withUnsafeMutableBufferPointer { buffer in
                ios_navigation_history_list_day_summaries(
                    directory,
                    buffer.baseAddress,
                    Int32(buffer.count)
                )
            }
        }

        let safeCount = max(0, min(Int(count), rawSummaries.count))
        return rawSummaries.prefix(safeCount).compactMap { raw in
            guard let dayKeyPointer = raw.dayKey else { return nil }
            return NavigationHistoryDaySummary(
                dayKey: String(cString: dayKeyPointer),
                startTimestampMs: Int64(raw.startTimestampMs),
                endTimestampMs: Int64(raw.endTimestampMs),
                pointCount: Int(raw.pointCount),
                alertEventCount: Int(raw.alertEventCount),
                distanceMeters: raw.distanceMeters
            )
        }
    }

    public func loadDay(dayKey: String) -> NavigationHistoryDay? {
        let jsonString: String? = withDirectoryAndDay(dayKey) { directory, day in
            guard let pointer = ios_navigation_history_load_day_json(directory, day) else {
                return nil
            }
            return String(cString: pointer)
        }

        guard let jsonString,
              let data = jsonString.data(using: .utf8) else { return nil }
        return try? decoder.decode(NavigationHistoryDay.self, from: data)
    }

    @discardableResult
    public func prune(retentionDays: Int = 90, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let startOfToday = calendar.startOfDay(for: now)
        let cutoff = calendar.date(
            byAdding: .day,
            value: -max(0, retentionDays - 1),
            to: startOfToday
        ) ?? startOfToday
        return prune(beforeDayKey: Self.dayKey(for: cutoff, calendar: calendar))
    }

    @discardableResult
    public func prune(beforeDayKey minimumDayKey: String) -> Int {
        withDirectoryAndDay(minimumDayKey) { directory, day in
            Int(ios_navigation_history_prune_before_day(directory, day))
        }
    }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func timestampMs(for date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000.0).rounded())
    }

    private func withDirectoryAndDay<T>(
        _ dayKey: String,
        _ body: (UnsafePointer<CChar>, UnsafePointer<CChar>) -> T
    ) -> T {
        directoryURL.path.withCString { directory in
            dayKey.withCString { day in
                body(directory, day)
            }
        }
    }
}
#endif
