import SwiftUI

// MARK: - Fortschritts-Ring (Tag / Woche / Monat / Jahr)

struct CircleRingView: View {
    let systemImage: String
    let progress: Double
    let label: String
    let remainingText: String
    var daysRemaining: Int? = nil

    private var ringColor: Color {
        switch progress {
        case ..<0.5:  return .green
        case ..<0.75: return Color(hue: 0.13, saturation: 0.95, brightness: 0.92)
        case ..<0.9:  return .orange
        default:      return .red
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.12), lineWidth: 4)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            VStack(spacing: 1) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: daysRemaining != nil ? 11 : 12,
                                  weight: .bold, design: .monospaced))
                    .foregroundStyle(ringColor)
                Text(label)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                if let days = daysRemaining {
                    Text("\(days)d")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(.secondary.opacity(0.65))
                }
            }
        }
        .frame(width: 56, height: 56)
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
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 3.5)

                    Circle()
                        .trim(from: 0, to: ringProgress)
                        .stroke(ringColor,
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: ringProgress)

                    Text(event.emoji)
                        .font(.system(size: 13))
                        .opacity(0.25)

                    VStack(spacing: 0) {
                        Text(daysLabel)
                            .font(.system(size: days > 99 ? 7 : 9,
                                          weight: .bold,
                                          design: .monospaced))
                            .foregroundStyle(days < 0 ? .secondary : .primary)
                        if !daysUnit.isEmpty {
                            Text(daysUnit)
                                .font(.system(size: 6, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 36, height: 36)

                Text(event.name)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 44)
            }
        }
        .buttonStyle(.plain)
    }
}
