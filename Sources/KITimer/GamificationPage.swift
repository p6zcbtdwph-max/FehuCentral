import SwiftUI
import EventKit

struct GamificationPage: View {
    @EnvironmentObject var gam: GamificationManager
    @EnvironmentObject var cal: CalendarManager

    var body: some View {
        VStack(spacing: 0) {
            if cal.authStatus != .fullAccess {
                noAccessView
            } else if gam.activities.isEmpty {
                loadingView
            } else {
                content
            }
        }
    }

    // MARK: - Hauptinhalt

    private var content: some View {
        ScrollView {
            VStack(spacing: 0) {
                levelCard
                Divider()
                activityList
                Spacer().frame(height: 12)
            }
        }
        .onAppear { gam.refresh() }
    }

    // MARK: - Level-Karte

    private var levelCard: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("⭐")
                    .font(.system(size: 22))
                Text("Level \(gam.level)")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                HStack(spacing: 4) {
                    Text("🔥")
                    Text("\(gam.streak)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.orange)
                    Text("Tage")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.yellow.opacity(0.85))
                            .frame(width: geo.size.width * gam.levelProgress, height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("\(gam.xpInLevel) XP")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("→ Level \(gam.level + 1) in \(100 - gam.xpInLevel) XP")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                statChip(value: "\(gam.totalXP)", label: "Gesamt XP")
                statChip(value: "\(gam.activities.count)", label: "Aktivitäten")
                statChip(value: "\(gam.activities.reduce(0) { $0 + $1.count })", label: "Termine")
            }
        }
        .padding(16)
    }

    // MARK: - Aktivitätenliste

    private var activityList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Erkannte Aktivitäten".uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("12 Wochen")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            ForEach(Array(gam.activities.enumerated()), id: \.element.id) { idx, activity in
                ActivityRow(activity: activity, rank: idx + 1)
            }
        }
    }

    // MARK: - Hilfselemente

    private func statChip(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
            Text("Kalender wird analysiert…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .onAppear { gam.refresh() }
    }

    private var noAccessView: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.calendar")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("Kein Kalender-Zugriff")
                .font(.system(size: 13, weight: .semibold))
            Text("Zugriff in Einstellungen → Apps erlauben.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

// MARK: - Einzelne Aktivitätszeile

struct ActivityRow: View {
    let activity: ActivityStat
    let rank: Int
    @State private var hovered = false

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .secondary.opacity(0.4)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("#\(rank)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(rankColor)
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 1) {
                Text(activity.title)
                    .font(.system(size: 12, weight: rank <= 3 ? .semibold : .regular))
                    .lineLimit(1)
                Text(activity.formattedTime)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(activity.count)×")
                    .font(.system(size: 12, weight: .semibold))
                Text("+\(activity.xp) XP")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow.opacity(0.8))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(hovered ? Color.secondary.opacity(0.06) : Color.clear)
        .onHover { hovered = $0 }
    }
}
