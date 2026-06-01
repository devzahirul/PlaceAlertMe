import Foundation

#if os(iOS)
import CoreMotion

internal protocol ActivityRecognitionDelegate: AnyObject {
    func activityRecognitionManager(_ manager: ActivityRecognitionManager, didDetectActivity activity: CMMotionActivity)
}

internal class ActivityRecognitionManager {
    weak var delegate: ActivityRecognitionDelegate?

    private let motionActivityManager = CMMotionActivityManager()
    private let operationQueue = OperationQueue()

    init() {
        operationQueue.maxConcurrentOperationCount = 1
    }

    func startActivityRecognition() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("Activity recognition not available on this device")
            return
        }

        let currentDate = Date()
        motionActivityManager.queryActivityStarting(from: currentDate, to: currentDate, to: operationQueue) { [weak self] activities, error in
            if let error = error {
                print("Activity recognition error: \(error.localizedDescription)")
                return
            }

            if let self, let activity = activities?.last {
                self.delegate?.activityRecognitionManager(self, didDetectActivity: activity)
            }
        }

        motionActivityManager.startActivityUpdates(to: operationQueue) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            self.delegate?.activityRecognitionManager(self, didDetectActivity: activity)
        }
    }

    func stopActivityRecognition() {
        motionActivityManager.stopActivityUpdates()
    }

    static func isActivityStill(_ activity: CMMotionActivity) -> Bool {
        return activity.stationary
    }

    static func isActivityMoving(_ activity: CMMotionActivity) -> Bool {
        return activity.walking || activity.running || activity.cycling || activity.automotive
    }

    static func status(from activity: CMMotionActivity) -> PlaceAlertActivityStatus {
        PlaceAlertActivityStatus(
            activityType: activityType(from: activity),
            confidence: confidence(from: activity.confidence),
            timestamp: activity.startDate
        )
    }

    private static func activityType(from activity: CMMotionActivity) -> PlaceAlertActivityType {
        if activity.automotive { return .automotive }
        if activity.cycling { return .cycling }
        if activity.running { return .running }
        if activity.walking { return .walking }
        if activity.stationary { return .stationary }
        return .unknown
    }

    private static func confidence(from confidence: CMMotionActivityConfidence) -> PlaceAlertActivityConfidence {
        switch confidence {
        case .low:
            return .low
        case .medium:
            return .medium
        case .high:
            return .high
        @unknown default:
            return .unknown
        }
    }
}
#endif
