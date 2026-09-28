import SwiftUI

// MARK: - Fortschritts-Ring (Tag / Woche / Monat / Jahr)

struct CircleRingView: View {
    let systemImage: String
    let progress: Double
    let label: String
    let remainingText: String

    private var ringColor: Color {
        switch progress {
        case ..<0.5:  return .green
        case ..<0.75: return Color(hue: 0.13, saturation: 0.95, brightness: 0.92)
        case ..<0.9:  return .orange
        default:      return .red
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // Hintergrund-Ring
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 5)

                // Fortschritts-Bogen
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)

                // Icon in der Mitte
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(width: 54, height: 54)

            // Prozentzahl
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(ringColor)

            // Label (Tag / Woche / Monat / Jahr)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .help(remainingText)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Countdown-Ring

struct CountdownCircleView: View {
    let event: CountdownEvent
    let onTap: () -> Void

    private var days: Int { event.daysRemaining() }

    private var ringColor: Color {
        if days < 0  { return .secondary }
        if days == 0 { return .green }
        if days <= 3 { return .red }
        if days <= 7 { return .orange }
        return Color.purple.opacity(0.8)
    }

    // Ring-Füllung: 0 Tage = voll, 90+ Tage = leer
    private var ringProgress: Double {
        guard days >= 0 else { return 0 }
        return max(0, min(1, 1.0 - Double(days) / 90.0))
    }

    private var daysLabel: String {
        if days < 0  { return "vorbei" }
        if days == 0 { return "Heute" }
        if days == 1 { return "1 Tag" }
        return "\(days)"
    }

    private var daysUnit: String {
        if days <= 1 || days < 0 { return "" }
        return "Tage"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    // Hintergrund-Ring
                    Circle()
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 5)

                    // Fortschritts-Bogen (Dringlichkeit)
                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(ringColor,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: ringProgress)

                    // Emoji als Hintergrund
                    Text(event.emoji)
                        .font(.system(size: 20))
                        .opacity(0.25)

                    // Tage-Zahl obendrauf
                    VStack(spacing: 0) {
                        Text(daysLabel)
                            .font(.system(size: days > 99 ? 10 : 13,
                                          weight: .bold,
                                          design: .monospaced))
                            .foregroundStyle(days < 0 ? .secondary : .primary)
                        if !daysUnit.isEmpty {
                            Text(daysUnit)
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 54, height: 54)

                // Name
                Text(event.name)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 62)
            }
        }
        .buttonStyle(.plain)
    }
}
