import Foundation
import CoreMotion

protocol ActivityRecognitionDelegate: AnyObject {
    func activityRecognitionManager(_ manager: ActivityRecognitionManager, didDetectActivity activity: CMMotionActivity)
}

class ActivityRecognitionManager {
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

            if let activity = activities?.last {
                self?.delegate?.activityRecognitionManager(self!, didDetectActivity: activity)
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
}
