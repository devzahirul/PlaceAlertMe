import SwiftUI
import CoreLocation
import UserNotifications
import PlaceAlertMe

struct SettingsView: View {
    @StateObject private var store = AlertStore.shared
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openURL) var openURL

    // MARK: - Persisted preferences
    @AppStorage("hasOnboarded") private var hasOnboarded: Bool = false
    @AppStorage("appearancePreference") private var appearancePreference: String = "system"
    @AppStorage("accentColorIndex") private var accentColorIndex: Int = 0
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("groupByPlace") private var groupByPlace: Bool = false
    @AppStorage("backgroundRefreshEnabled") private var backgroundRefreshEnabled: Bool = true
    @AppStorage("batterySaverEnabled") private var batterySaverEnabled: Bool = false

    // MARK: - Local UI state
    @State private var showingAccentPicker = false
    @State private var showingReplayConfirm = false
    @State private var showingClearConfirm = false
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
    @State private var locationAuthStatus: CLAuthorizationStatus = .notDetermined

    // MARK: - Derived
    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }
    var bgColor: Color { colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight }

    var currentAccent: Color {
        let safe = max(0, min(accentColorIndex, RounderTheme.accents.count - 1))
        return RounderTheme.accents[safe].color
    }

    var currentAccentName: String {
        let safe = max(0, min(accentColorIndex, RounderTheme.accents.count - 1))
        return RounderTheme.accents[safe].name
    }

    var darkModeBinding: Binding<Bool> {
        Binding(
            get: { appearancePreference == "dark" },
            set: { appearancePreference = $0 ? "dark" : "light" }
        )
    }

    /// Binding for the Background refresh toggle. With the Life360-parity engine,
    /// CLCircularRegion monitoring is automatic while tracking is active, so the
    /// toggle maps to start/stop tracking. Starting reloads the persisted zones
    /// (PlaceStore) and re-registers their regions; stopping tears them down.
    var backgroundRefreshBinding: Binding<Bool> {
        Binding(
            get: { backgroundRefreshEnabled },
            set: { newValue in
                backgroundRefreshEnabled = newValue
                if newValue {
                    PlaceAlertMe.shared.startTracking()
                } else {
                    PlaceAlertMe.shared.stopTracking()
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                accountSection
                notificationsSection
                locationSection
                appearanceSection
                demoSection
                versionFooter
            }
            .padding(.top, 8)
        }
        .background(bgColor.ignoresSafeArea())
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                MonoLabel(text: "ROUNDER")
            }
        }
        .onAppear {
            refreshPermissionStatuses()
        }
        .sheet(isPresented: $showingAccentPicker) {
            AccentPickerSheet(selectedIndex: $accentColorIndex)
                .presentationDetents([.medium])
        }
        .alert("Replay onboarding?", isPresented: $showingReplayConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Replay") { hasOnboarded = false }
        } message: {
            Text("You'll see the welcome tour the next time you open the app. Your pinned places will not be removed.")
        }
        .alert("Clear all pins?", isPresented: $showingClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear all", role: .destructive) { store.clearAllAlerts() }
        } message: {
            Text("This permanently deletes all \(store.alerts.count) pinned place(s). This can't be undone.")
        }
    }

    // MARK: - Account Section
    private var accountSection: some View {
        GroupedSection {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(currentAccent)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text("R")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Rounder User")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(textColor)

                        Text("user@rounder.app")
                            .font(.system(size: 13))
                            .foregroundColor(mutedColor)
                    }

                    Spacer()
                }

                Divider()

                SettingRow(label: "Subscription", value: "Free")
                SettingRow(label: "Sync devices", value: "Not synced")
            }
            .padding(24)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Notifications Section
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoLabel(text: "NOTIFICATIONS")
                .padding(.horizontal, 24)

            GroupedSection {
                VStack(spacing: 16) {
                    SettingRow(
                        label: "System permission",
                        value: notificationStatusLabel,
                        action: notificationsRowAction
                    )
                    Divider()
                    SettingToggleRow(label: "Sound", value: $soundEnabled)
                    Divider()
                    SettingToggleRow(label: "Haptics", value: $hapticsEnabled)
                    Divider()
                    SettingToggleRow(label: "Group by place", value: $groupByPlace)
                }
                .padding(24)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Location Section
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoLabel(text: "LOCATION")
                .padding(.horizontal, 24)

            GroupedSection {
                VStack(spacing: 16) {
                    SettingRow(
                        label: "Permission",
                        value: locationStatusLabel,
                        action: openAppSettings
                    )
                    Divider()
                    SettingToggleRow(label: "Background refresh", value: backgroundRefreshBinding)
                    Divider()
                    SettingToggleRow(label: "Battery saver", value: $batterySaverEnabled)
                }
                .padding(24)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Appearance Section
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoLabel(text: "APPEARANCE")
                .padding(.horizontal, 24)

            GroupedSection {
                VStack(spacing: 16) {
                    SettingToggleRow(label: "Dark mode", value: darkModeBinding)
                    Divider()
                    SettingRow(
                        label: "Accent color",
                        value: currentAccentName,
                        action: { showingAccentPicker = true }
                    )
                    Divider()
                    SettingRow(label: "Language", value: "English")
                }
                .padding(24)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Demo Section
    private var demoSection: some View {
        GroupedSection {
            VStack(spacing: 16) {
                Button(action: { showingReplayConfirm = true }) {
                    HStack {
                        Text("Replay onboarding")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(textColor)
                }

                Divider()

                Button(action: { showingClearConfirm = true }) {
                    HStack {
                        Text("Clear all pins")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(RounderTheme.danger)
                }
                .disabled(store.alerts.isEmpty)
                .opacity(store.alerts.isEmpty ? 0.4 : 1)
            }
            .padding(24)
        }
        .padding(.horizontal, 24)
    }

    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("ROUNDER v 1.0.0 · BUILD 240")
                .font(.system(size: 10).monospaced())
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundColor(mutedColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.bottom, 40)
    }

    // MARK: - Helpers

    private var notificationStatusLabel: String {
        switch notificationAuthStatus {
        case .authorized:  return "Allowed"
        case .denied:      return "Denied"
        case .notDetermined: return "Not set"
        case .provisional: return "Provisional"
        case .ephemeral:   return "Ephemeral"
        @unknown default:  return "Unknown"
        }
    }

    private var locationStatusLabel: String {
        switch locationAuthStatus {
        case .authorizedAlways:     return "Always"
        case .authorizedWhenInUse:  return "While Using"
        case .denied:               return "Denied"
        case .restricted:           return "Restricted"
        case .notDetermined:        return "Not set"
        @unknown default:           return "Unknown"
        }
    }

    private func refreshPermissionStatuses() {
        // Location — synchronous on iOS 14+.
        if #available(iOS 14.0, *) {
            locationAuthStatus = CLLocationManager().authorizationStatus
        } else {
            locationAuthStatus = CLLocationManager.authorizationStatus()
        }

        // Notifications — async.
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationAuthStatus = settings.authorizationStatus
            }
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    /// `nil` if notifications are already authorized (nothing for the user
    /// to do); otherwise tapping the row opens the iOS Settings app so
    /// the user can flip the switch.
    private var notificationsRowAction: (() -> Void)? {
        if notificationAuthStatus == .authorized {
            return nil
        }
        return { openAppSettings() }
    }
}

// MARK: - Accent Picker Sheet
struct AccentPickerSheet: View {
    @Binding var selectedIndex: Int
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var bgColor: Color { colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    MonoLabel(text: "ACCENT COLOR")
                    Spacer()
                    Button("Done") { dismiss() }
                        .foregroundColor(textColor)
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    ForEach(Array(RounderTheme.accents.enumerated()), id: \.offset) { index, accent in
                        Button(action: { selectedIndex = index }) {
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(accent.color)
                                        .frame(width: 56, height: 56)

                                    if index == selectedIndex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .overlay(
                                    Circle()
                                        .stroke(textColor, lineWidth: index == selectedIndex ? 2 : 0)
                                )

                                Text(accent.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(textColor)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}

// MARK: - Setting Row Components
struct SettingRow: View {
    let label: String
    let value: String
    var action: (() -> Void)? = nil
    @Environment(\.colorScheme) var colorScheme

    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }

    var body: some View {
        Button(action: { action?() }) {
            HStack {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(textColor)

                Spacer()

                HStack(spacing: 4) {
                    Text(value)
                        .font(.system(size: 15))
                        .foregroundColor(mutedColor)

                    if action != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(mutedColor)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(action == nil)
        .buttonStyle(.plain)
    }
}

struct SettingToggleRow: View {
    let label: String
    @Binding var value: Bool
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("accentColorIndex") private var accentColorIndex: Int = 0

    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }

    private var currentAccent: Color {
        let safe = max(0, min(accentColorIndex, RounderTheme.accents.count - 1))
        return RounderTheme.accents[safe].color
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(textColor)

            Spacer()

            OutlineToggle(isOn: $value, accentColor: currentAccent)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
