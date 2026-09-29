import SwiftUI
import EventKit

struct GamificationPage: View {
    @EnvironmentObject var gam: GamificationManager
    @EnvironmentObject var cal: CalendarManager

    var body: some View {
        if cal.authStatus != .fullAccess {
            noAccessView
        } else if gam.activities.isEmpty {
            emptyView
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    headerCard
                    Divider()
                    activityList
                    Spacer().frame(height: 12)
                }
            }
            .onAppear { gam.refresh() }
        }
    }

    // MARK: - Header-Karte

    private var headerCard: some View {
        VStack(spacing: 12) {
            // Rang + Level
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        rankBadge(gam.rank, size: .large)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Level \(gam.overallLevel)")
                                .font(.system(size: 20, weight: .bold))
                            Text(gam.rank.name)
                                .font(.system(size: 12))
                                .foregroundStyle(rankColor(gam.rank))
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("🔥").font(.system(size: 14))
                        Text("\(gam.streak)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    Text("Tage Streak")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            // XP-Balken
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(rankColor(gam.rank).opacity(0.8))
                            .frame(width: geo.size.width * gam.overallProgress, height: 8)
                    }
                }
                .frame(height: 8)
                HStack {
                    Text("\(gam.totalXP) XP")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    if let next = gam.rank.nextRankLevel {
                        Text("→ \(GamificationManager.rankInfo(forLevel: next).name) ab Level \(next)")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    } else {
                        Text("Maximaler Rang erreicht")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }

            // Stat-Chips
            HStack(spacing: 8) {
                statChip("\(gam.activities.count)", "Aktivitäten")
                statChip("\(gam.activities.reduce(0) { $0 + $1.count })", "Termine")
                statChip(formattedTotalTime, "Gesamt-Zeit")
            }
        }
        .padding(16)
    }

    private var formattedTotalTime: String {
        let total = gam.activities.reduce(0) { $0 + $1.totalMinutes }
        let h = total / 60; let m = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    // MARK: - Aktivitätenliste

    private var activityList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Aktivitäten".uppercased())
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Button(action: { gam.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            ForEach(gam.activities) { activity in
                ActivityDetailRow(activity: activity)
                    .environmentObject(gam)
            }
        }
    }

    // MARK: - Hilfselemente

    private func statChip(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 13, weight: .semibold))
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 6)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func rankBadge(_ rank: GamificationManager.RankInfo, size: BadgeSize) -> some View {
        ZStack {
            Circle()
                .fill(rankColor(rank).opacity(0.15))
                .frame(width: size == .large ? 44 : 28, height: size == .large ? 44 : 28)
            Text(rank.roman)
                .font(.system(size: size == .large ? 16 : 11, weight: .bold))
                .foregroundStyle(rankColor(rank))
        }
    }

    enum BadgeSize { case large, small }

    private func rankColor(_ rank: GamificationManager.RankInfo) -> Color {
        switch rank.roman {
        case "I":   return .secondary
        case "II":  return .blue
        case "III": return .green
        case "IV":  return .purple
        default:    return Color(red: 1, green: 0.78, blue: 0)
        }
    }

    // MARK: - Leer-/Fehlerzustände

    private var emptyView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Kalender wird analysiert…")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Text("Braucht einen Moment beim ersten Start.")
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 32)
        .onAppear { gam.refresh() }
    }

    private var noAccessView: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.calendar")
                .font(.system(size: 28)).foregroundStyle(.secondary)
            Text("Kein Kalender-Zugriff")
                .font(.system(size: 13, weight: .semibold))
            Text("Zugriff in Einstellungen → Apps erlauben.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(24)
    }
}

// MARK: - Einzelne Aktivitätszeile

struct ActivityDetailRow: View {
    let activity: ActivityStat
    @EnvironmentObject var gam: GamificationManager
    @State private var hovered   = false
    @State private var showEdit  = false
    @State private var editXPH   = 100

    var body: some View {
        HStack(spacing: 10) {
            // Level-Badge der Aktivität
            ZStack {
                Circle()
                    .fill(activityLevelColor.opacity(0.12))
                    .frame(width: 28, height: 28)
                Text("\(activity.activityLevel)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(activityLevelColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(activity.count)×")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(activity.formattedTime)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(activity.xpPerHour) XP/h")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(activity.earnedXP) XP")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.yellow.opacity(0.9))

                // Mini-Fortschrittsbalken
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(activityLevelColor.opacity(0.7))
                            .frame(width: geo.size.width * activity.activityProgress, height: 3)
                    }
                }
                .frame(width: 48, height: 3)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(hovered ? Color.secondary.opacity(0.06) : Color.clear)
        .onHover { hovered = $0 }
        .contextMenu {
            Button(action: { editXPH = activity.xpPerHour; showEdit = true }) {
                Label("XP/h anpassen", systemImage: "slider.horizontal.3")
            }
            Divider()
            Button(role: .destructive, action: { gam.addToBlacklist(activity.title) }) {
                Label("Blockieren", systemImage: "nosign")
            }
        }
        .popover(isPresented: $showEdit, arrowEdge: .trailing) {
            xpEditor
        }
    }

    private var xpEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("XP pro Stunde")
                .font(.system(size: 12, weight: .semibold))
            Text(activity.title)
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .lineLimit(1)
            HStack {
                Text("\(editXPH) XP/h")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .frame(width: 80)
                Stepper("", value: $editXPH, in: 10...500, step: 10)
                    .labelsHidden()
            }
            Button("Speichern") {
                gam.setXPPerHour(editXPH, for: activity.title)
                showEdit = false
            }
            .buttonStyle(.borderedProminent).controlSize(.small)
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .frame(width: 200)
    }

    private var activityLevelColor: Color {
        let lv = activity.activityLevel
        switch lv {
        case ...4:    return .secondary
        case 5...9:   return .blue
        case 10...14: return .green
        case 15...19: return .purple
        default:      return Color(red: 1, green: 0.78, blue: 0)
        }
    }
}
