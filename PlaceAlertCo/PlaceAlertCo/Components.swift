import SwiftUI
import MapKit

// MARK: - MonoLabel Component
struct MonoLabel: View {
    let text: String
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundColor(colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight)
    }
}

// MARK: - OutlineButton Component
struct OutlineBtn: View {
    let label: String
    let action: () -> Void
    var primary: Bool = false
    var accent: Color = RounderTheme.accents[0].color
    var size: Size = .md
    var full: Bool = false

    @Environment(\.colorScheme) var colorScheme

    enum Size {
        case sm, md, lg
        var height: CGFloat {
            switch self {
            case .sm: return 36
            case .md: return 44
            case .lg: return 52
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .sm: return 13
            case .md: return 14
            case .lg: return 16
            }
        }
    }

    var bgColor: Color {
        primary ? accent : .clear
    }

    var textColor: Color {
        primary ? (accent == RounderTheme.accents[0].color ? .white : .white) : (colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight)
    }

    var borderColor: Color {
        colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: size.fontSize, weight: .semibold))
                .foregroundColor(textColor)
                .frame(height: size.height)
                .frame(maxWidth: full ? .infinity : nil)
                .background(bgColor, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: 1.25)
                )
        }
    }
}

// MARK: - OutlineToggle Component
struct OutlineToggle: View {
    @Binding var isOn: Bool
    @Environment(\.colorScheme) var colorScheme

    var accentColor: Color = RounderTheme.accents[0].color

    var bgColor: Color {
        colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight
    }

    var borderColor: Color {
        colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight
    }

    var body: some View {
        Button(action: { isOn.toggle() }) {
            ZStack {
                Capsule()
                    .fill(isOn ? accentColor : bgColor)
                    .stroke(borderColor, lineWidth: 1.25)

                Circle()
                    .fill(isOn ? .white : borderColor)
                    .frame(width: 20, height: 20)
                    .padding(2)
                    .offset(x: isOn ? 8 : -8)
            }
            .frame(width: 44, height: 26)
        }
    }
}

// MARK: - OutlineCard Component
struct OutlineCard<Content: View>: View {
    let content: () -> Content
    @Environment(\.colorScheme) var colorScheme

    var borderColor: Color {
        colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight
    }

    var bgColor: Color {
        colorScheme == .dark ? RounderTheme.surfaceDark : RounderTheme.surfaceLight
    }

    var body: some View {
        VStack {
            content()
        }
        .background(bgColor, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: 1.25)
        )
    }
}

// MARK: - Outline Map Thumbnail
struct OutlineMapThumbnail: View {
    let latitude: Double
    let longitude: Double
    let radiusMeters: Double = 500
    var accent: Color = RounderTheme.accents[0].color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(colorScheme == .dark ? RounderTheme.surface2Dark : RounderTheme.surface2Light)

            // Map placeholder with Map view
            Map(position: .constant(.region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))))
            .mapStyle(.standard)
            .overlay(
                // Geofence circle overlay
                Circle()
                    .stroke(accent.opacity(0.6), lineWidth: 2)
                    .frame(width: 40, height: 40)
            )

            // Geofence center dot
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
        }
        .cornerRadius(12)
    }
}

// MARK: - Tab Bar Item
struct TabBarItem: View {
    let icon: String
    let label: String
    let isActive: Bool
    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color {
        colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight
    }

    var borderColor: Color {
        colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))

            if isActive {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .foregroundColor(isActive ? .white : borderColor)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(isActive ? borderColor : bgColor)
        .cornerRadius(12)
    }
}

// MARK: - Floating FAB
struct FloatingActionButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var bgColor: Color {
        colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(bgColor)
                .cornerRadius(25)
                .shadow(radius: 4)
        }
    }
}

// MARK: - Live Tracking Badge
struct LiveBadge: View {
    let count: Int
    var isLive: Bool = true
    @Environment(\.colorScheme) var colorScheme
    @State private var pulse = false

    var borderColor: Color {
        colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight
    }

    var idleDotColor: Color {
        colorScheme == .dark ? RounderTheme.softDark : RounderTheme.softLight
    }

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                // Pulse ring (only when live)
                if isLive {
                    Circle()
                        .fill(RounderTheme.success.opacity(0.35))
                        .frame(width: 14, height: 14)
                        .scaleEffect(pulse ? 1.6 : 1.0)
                        .opacity(pulse ? 0 : 1)
                        .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)
                }
                Circle()
                    .fill(isLive ? RounderTheme.success : idleDotColor)
                    .frame(width: 8, height: 8)
            }
            .frame(width: 14, height: 14)

            Text("\(count)")
                .font(.system(size: 12, weight: .semibold))

            Text(isLive ? "Live" : "Idle")
                .font(.system(size: 12))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 1)
        )
        .onAppear { if isLive { pulse = true } }
        .onChange(of: isLive) { _, newValue in
            pulse = newValue
        }
    }
}

// MARK: - Step Indicator Dots
struct StepDots: View {
    let currentStep: Int
    let totalSteps: Int
    @Environment(\.colorScheme) var colorScheme

    var borderColor: Color {
        colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .strokeBorder(borderColor, lineWidth: 1)
                    .background(i == currentStep ? borderColor : .clear, in: Capsule())
                    .frame(width: i == currentStep ? 22 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
            }
        }
    }
}

// MARK: - Grouped Section
struct GroupedSection<Content: View>: View {
    let content: () -> Content
    @Environment(\.colorScheme) var colorScheme

    var borderColor: Color {
        colorScheme == .dark ? RounderTheme.softDark : RounderTheme.softLight
    }

    var bgColor: Color {
        colorScheme == .dark ? RounderTheme.surfaceDark : RounderTheme.surfaceLight
    }

    var body: some View {
        VStack {
            content()
        }
        .background(bgColor, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1.25)
        )
    }
}
