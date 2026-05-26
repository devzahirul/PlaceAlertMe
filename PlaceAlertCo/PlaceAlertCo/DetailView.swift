import SwiftUI

struct DetailView: View {
    let alert: Alert
    let accentColor: Color
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var store = AlertStore.shared
    @Environment(\.colorScheme) var colorScheme

    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }
    var bgColor: Color { colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Map
                OutlineMapThumbnail(
                    latitude: alert.latitude,
                    longitude: alert.longitude,
                    accent: accentColor
                )
                .frame(height: 260)
                .padding(.horizontal, 24)
                .padding(.top, 12)

                // Title Block
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: alert.trigger == .arriving ? "arrow.up.right" : "arrow.down.left")
                            .font(.system(size: 10))

                        Text("\(alert.trigger.rawValue) · \(Int(alert.radiusMeters))M")
                            .font(.system(size: 10).monospaced())
                            .textCase(.uppercase)

                        Spacer()
                    }
                    .foregroundColor(mutedColor)

                    Text(alert.task)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(textColor)
                        .lineLimit(3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.place)
                            .font(.system(size: 15, weight: .semibold))

                        Text(alert.address)
                            .font(.system(size: 13))
                            .foregroundColor(mutedColor)
                    }
                    .foregroundColor(textColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatTile(label: "Distance", value: "2.4 km", accentColor: accentColor)
                    StatTile(label: "Status", value: "Active", accentColor: RounderTheme.success)
                    StatTile(label: "Trigger", value: alert.trigger.rawValue, accentColor: accentColor)
                    StatTile(label: "Last Fired", value: alert.lastFired?.formatted(date: .abbreviated, time: .omitted) ?? "Never", accentColor: mutedColor)
                }
                .padding(.horizontal, 24)

                // Options Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("OPTIONS")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(mutedColor)
                        .padding(.horizontal, 24)

                    GroupedSection {
                        VStack(spacing: 12) {
                            OptionRow(label: "Active", isToggle: true) {
                                OutlineToggle(
                                    isOn: Binding(
                                        get: { alert.isActive },
                                        set: { _ in store.toggleAlertActive(id: alert.id) }
                                    ),
                                    accentColor: accentColor
                                )
                            }

                            Divider()

                            OptionRow(label: "Repeat", isToggle: false) {
                                HStack {
                                    Text("Daily")
                                        .foregroundColor(.secondary)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Divider()

                            OptionRow(label: "Sound", isToggle: false) {
                                HStack {
                                    Text("Default")
                                        .foregroundColor(.secondary)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(24)
                    }
                    .padding(.horizontal, 24)
                }

                // Note
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTE")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(mutedColor)

                    TextEditor(text: .constant(alert.note.isEmpty ? "Add a note..." : alert.note))
                        .font(.system(size: 15))
                        .frame(minHeight: 100)
                        .padding(12)
                        .background(colorScheme == .dark ? RounderTheme.surface2Dark : RounderTheme.surface2Light, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                                .foregroundColor(mutedColor)
                        )
                }
                .padding(.horizontal, 24)

                // Test Button — fires a real notification so user can confirm
                // banners actually appear (verifies the foreground delegate +
                // permission state without needing to physically walk into the
                // geofence).
                OutlineBtn(
                    label: "Test notification",
                    action: {
                        store.sendTestNotification(for: alert)
                        store.logNotificationStatus()
                    },
                    primary: false,
                    size: .lg,
                    full: true
                )
                .padding(24)

                Spacer()
            }
        }
        .background(bgColor.ignoresSafeArea())
        .navigationTitle(alert.place)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "pencil")
                        .foregroundColor(textColor)
                }

                Button(action: {
                    store.deleteAlert(id: alert.id)
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(RounderTheme.danger)
                }
            }
        }
    }
}

// MARK: - Stat Tile
struct StatTile: View {
    let label: String
    let value: String
    let accentColor: Color
    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color { colorScheme == .dark ? RounderTheme.surfaceDark : RounderTheme.surfaceLight }
    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(.gray)

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(textColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(bgColor, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colorScheme == .dark ? RounderTheme.softDark : RounderTheme.softLight, lineWidth: 1.25)
        )
    }
}

// MARK: - Option Row
struct OptionRow<Content: View>: View {
    let label: String
    let isToggle: Bool
    let content: () -> Content

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            content()
        }
    }
}

#Preview {
    NavigationStack {
        DetailView(alert: Alert.samples[0], accentColor: RounderTheme.accents[0].color)
    }
}
