//
//  PlaceAlertCoApp.swift
//  PlaceAlertCo
//
//  Created by lynkto_1 on 5/21/26.
//

import SwiftUI
import Combine
import CoreLocation

#if os(iOS)
@main
struct PlaceAlertCoApp: App {
    @StateObject private var locationManager = AppLocationManager()

    // Global appearance setting — driven by SettingsView's Dark Mode toggle.
    // `nil` keeps `.system` so the OS picks. `dark`/`light` override.
    @AppStorage("appearancePreference") private var appearancePreference: String = "system"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .preferredColorScheme(resolvedColorScheme)
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch appearancePreference {
        case "dark":  return .dark
        case "light": return .light
        default:      return nil   // follow system
        }
    }
}
#endif

#if os(iOS)
class AppLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        locationManager.delegate = self

        // Only check current status — DO NOT request permission here.
        if #available(iOS 14.0, *) {
            authorizationStatus = locationManager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }

        print("📍 [AppLocationManager init] Current status: \(Self.statusName(authorizationStatus))")

        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            AlertStore.shared.initializeGeofencingAfterPermissions()
        }
    }

    /// Explicitly trigger the iOS location-permission popup.
    /// Called from OnboardingView when user taps "Allow location".
    func requestLocationPermission() {
        // Read fresh value — @Published copy may be stale.
        let current: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            current = locationManager.authorizationStatus
        } else {
            current = CLLocationManager.authorizationStatus()
        }

        print("📍 [requestLocationPermission] Status: \(Self.statusName(current))")

        switch current {
        case .notDetermined:
            print("📍 Calling requestAlwaysAuthorization() — popup should appear")
            locationManager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            print("📍 Upgrading to Always authorization")
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            print("✅ Already authorized Always")
        case .denied, .restricted:
            print("⚠️ Permission denied — opening Settings")
            openAppSettings()
        @unknown default:
            print("❓ Unknown status: \(current.rawValue)")
        }
    }

    private func openAppSettings() {
        DispatchQueue.main.async {
            if let url = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }

    private static func statusName(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = manager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = status
        }

        if status == .authorizedAlways || status == .authorizedWhenInUse {
            print("✅ Location permission granted: \(status.rawValue)")
            AlertStore.shared.initializeGeofencingAfterPermissions()
        } else if status == .denied {
            print("❌ Location permission denied")
        }
    }
}
#endif
