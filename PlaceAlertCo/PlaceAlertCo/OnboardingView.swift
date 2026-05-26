import SwiftUI

struct OnboardingView: View {
    @State private var step = 0
    @AppStorage("hasOnboarded") var hasOnboarded = false
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var locationManager: AppLocationManager

    var accentColor: Color = RounderTheme.accents[0].color

    let steps: [(label: String, title: String, body: String, cta: String)] = [
        ("01 / 03", "Reminders\nthat know where\nyou are.", "Rounder pins a reminder to a place. When you get within range, your phone gently taps you. Nothing happens in the cloud.", "Start"),
        ("02 / 03", "Allow location\nwhile using the app.", "We monitor up to 20 places at once using a low-power geofence. Background location lets us alert you even when Rounder is closed.", "Allow location"),
        ("03 / 03", "Let us send\nnotifications.", "You'll only hear from us when you cross into a place you set up. No marketing. Ever.", "Enable notifications"),
    ]

    var bgColor: Color { colorScheme == .dark ? RounderTheme.bgDark : RounderTheme.bgLight }
    var textColor: Color { colorScheme == .dark ? RounderTheme.inkDark : RounderTheme.inkLight }
    var mutedColor: Color { colorScheme == .dark ? RounderTheme.mutedDark : RounderTheme.mutedLight }

    var currentStep: (label: String, title: String, body: String, cta: String) { steps[step] }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 28) {
                    MonoLabel(text: "ROUNDER · \(currentStep.label)")
                        .padding(.top, 24)
                        .padding(.horizontal, 24)

                    // Artwork Circle
                    ZStack {
                        Circle()
                            .stroke(textColor, lineWidth: 1.25)

                        OnboardingArtwork(step: step, accentColor: accentColor, isDark: colorScheme == .dark)
                    }
                    .frame(width: 220, height: 220)
                    .padding(.horizontal, 24)

                    // Title
                    VStack(alignment: .leading, spacing: 14) {
                        Text(currentStep.title)
                            .font(.system(size: 34, weight: .bold))
                            .tracking(-1.2)
                            .lineSpacing(1.05)
                            .foregroundColor(textColor)

                        Text(currentStep.body)
                            .font(.system(size: 15, weight: .regular))
                            .lineSpacing(1.5)
                            .foregroundColor(mutedColor)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                // Bottom Controls
                VStack(spacing: 12) {
                    // Step Dots
                    StepDots(currentStep: step, totalSteps: 3)
                        .padding(.bottom, 18)

                    // CTA Button
                    OutlineBtn(
                        label: currentStep.cta,
                        action: { handleCTATap() },
                        primary: true,
                        accent: accentColor,
                        size: .lg,
                        full: true
                    )

                    // Maybe Later (skip without requesting permission)
                    if step > 0 {
                        Button(action: { advanceOrFinish() }) {
                            Text("Maybe later")
                                .font(.system(size: 13))
                                .foregroundColor(mutedColor)
                        }
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - CTA Actions

    /// Handle the primary CTA button — request the relevant permission
    /// for the current step, then advance.
    private func handleCTATap() {
        print("🔘 [Onboarding] CTA tapped on step \(step)")
        switch step {
        case 0:
            step += 1
        case 1:
            print("🔘 [Onboarding] Triggering location permission request...")
            locationManager.requestLocationPermission()
            step += 1
        case 2:
            print("🔘 [Onboarding] Triggering notification permission request...")
            AlertStore.shared.requestNotificationPermission()
            hasOnboarded = true
        default:
            break
        }
    }

    /// Skip without requesting — for "Maybe later"
    private func advanceOrFinish() {
        if step == 2 {
            hasOnboarded = true
        } else {
            step += 1
        }
    }
}

// MARK: - Onboarding Artwork
struct OnboardingArtwork: View {
    let step: Int
    let accentColor: Color
    let isDark: Bool

    var textColor: Color { isDark ? RounderTheme.inkDark : RounderTheme.inkLight }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            switch step {
            case 0:
                // Concentric rings + compass
                drawConcentricRings(context: &context, center: center, color: textColor)

            case 1:
                // Grid + geofence circles
                drawGridGeofence(context: &context, center: center, color: textColor)

            case 2:
                // Stacked notifications
                drawNotifications(context: &context, center: center, color: textColor)

            default:
                break
            }
        }
        .frame(width: 220, height: 220)
    }

    // MARK: - Drawing Functions
    private func drawConcentricRings(context: inout GraphicsContext, center: CGPoint, color: Color) {
        let radii: [CGFloat] = [20, 40, 60, 80]

        for (i, r) in radii.enumerated() {
            var stroke = StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round)
            if i % 2 == 1 {
                stroke.dash = [3, 3]
            }

            let path = Circle().path(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            context.stroke(path, with: .color(color), style: stroke)
        }

        // Compass cross (dashed)
        var horizPath = Path()
        horizPath.move(to: CGPoint(x: 30, y: center.y))
        horizPath.addLine(to: CGPoint(x: center.x + 100, y: center.y))

        context.stroke(horizPath, with: .color(color), style: StrokeStyle(lineWidth: 1.25, dash: [2, 4]))

        var vertPath = Path()
        vertPath.move(to: CGPoint(x: center.x, y: 30))
        vertPath.addLine(to: CGPoint(x: center.x, y: center.y + 100))

        context.stroke(vertPath, with: .color(color), style: StrokeStyle(lineWidth: 1.25, dash: [2, 4]))

        // Center dot
        let dotPath = Circle().path(in: CGRect(x: center.x - 4.5, y: center.y - 4.5, width: 9, height: 9))
        context.fill(dotPath, with: .color(accentColor))
    }

    private func drawGridGeofence(context: inout GraphicsContext, center: CGPoint, color: Color) {
        // Grid pattern
        let gridSpacing: CGFloat = 20
        for i in 0..<11 {
            let offset = CGFloat(i) * gridSpacing - 100

            var hLine = Path()
            hLine.move(to: CGPoint(x: center.x - 100, y: center.y + offset))
            hLine.addLine(to: CGPoint(x: center.x + 100, y: center.y + offset))
            context.stroke(hLine, with: .color(color), style: StrokeStyle(lineWidth: 0.5))

            var vLine = Path()
            vLine.move(to: CGPoint(x: center.x + offset, y: center.y - 100))
            vLine.addLine(to: CGPoint(x: center.x + offset, y: center.y + 100))
            context.stroke(vLine, with: .color(color), style: StrokeStyle(lineWidth: 0.5))
        }

        // Geofence circles
        let radii: [CGFloat] = [30, 60]
        for r in radii {
            let path = Circle().path(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
            context.stroke(path, with: .color(accentColor), style: StrokeStyle(lineWidth: 1.5))
        }

        // Center dot
        let dotPath = Circle().path(in: CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7, height: 7))
        context.fill(dotPath, with: .color(accentColor))
    }

    private func drawNotifications(context: inout GraphicsContext, center: CGPoint, color: Color) {
        // Stacked notification cards
        let cardHeight: CGFloat = 28
        let cardWidth: CGFloat = 140
        let spacing: CGFloat = 16

        for i in 0..<3 {
            let yOffset = center.y - cardHeight + CGFloat(i) * spacing
            let path = RoundedRectangle(cornerRadius: 6).path(in: CGRect(x: center.x - cardWidth / 2, y: yOffset, width: cardWidth, height: cardHeight))
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1))
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppLocationManager())
}
