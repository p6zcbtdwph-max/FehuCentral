import SwiftUI
import EventKit

struct GamificationPage: View {
    @EnvironmentObject var gam: GamificationManager
    @EnvironmentObject var cal: CalendarManager

    var body: some View {
        if cal.authStatus != .fullAccess {
            noAccessView
        } else if gam.activities.isEmpty && gam.blacklist.isEmpty {
            emptyView
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    if !gam.activities.isEmpty {
                        headerCard
                        Divider()
                        activityList
                    }
                    if !gam.blacklist.isEmpty {
                        Divider()
                        blacklistSection
                    }
                    Spacer().frame(height: 12)
                }
            }
            .onAppear { gam.refresh() }
        }
    }

    // MARK: - Header-Karte

    private var headerCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        tierBadge(gam.rank, large: true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Level \(gam.overallLevel)")
                                .font(.system(size: 20, weight: .bold))
                            Text("\(gam.rank.name) \(gam.rank.roman)")
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
                    } else if gam.overallLevel < 20 {
                        EmptyView()
                    } else {
                        Text("Level \(gam.overallLevel + 1) in \(GamificationManager.xpNeeded(toReach: gam.overallLevel + 1) - gam.totalXP) XP")
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

    // MARK: - Blacklist

    private var blacklistSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Gesperrt".uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

            ForEach(Array(gam.blacklist).sorted(), id: \.self) { title in
                HStack(spacing: 10) {
                    Image(systemName: "nosign")
                        .font(.system(size: 11))
                        .foregroundStyle(.red.opacity(0.5))
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { gam.removeFromBlacklist(title) }) {
                        Text("Entsperren")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Rang-Badge

    private func tierBadge(_ rank: GamificationManager.RankInfo, large: Bool) -> some View {
        let dim: CGFloat = large ? 44 : 28
        let color = rankColor(rank)
        return ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: dim, height: dim)
            VStack(spacing: large ? 0 : -1) {
                Text(rank.name.prefix(large ? 2 : 1).uppercased())
                    .font(.system(size: large ? 9 : 7, weight: .semibold))
                    .foregroundStyle(color.opacity(0.8))
                Text(rank.roman)
                    .font(.system(size: large ? 14 : 10, weight: .bold))
                    .foregroundStyle(color)
            }
        }
    }

    private func rankColor(_ rank: GamificationManager.RankInfo) -> Color {
        switch rank.name {
        case "Bronze":  return Color(red: 0.80, green: 0.52, blue: 0.25)
        case "Silber":  return Color(red: 0.65, green: 0.65, blue: 0.70)
        case "Gold":    return Color(red: 1.00, green: 0.78, blue: 0.00)
        case "Platin":  return Color(red: 0.40, green: 0.82, blue: 1.00)
        case "Diamant": return Color(red: 0.60, green: 0.40, blue: 1.00)
        default:        return .secondary
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
    @State private var hovered  = false
    @State private var showEdit = false
    @State private var editXPH  = 100

    var body: some View {
        HStack(spacing: 10) {
            tierBadgeSmall

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(activity.count)×")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    Text(activity.formattedTime)
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    Text("\(activity.xpPerHour) XP/h")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(activity.earnedXP) XP")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.yellow.opacity(0.9))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.12))
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(tierColor.opacity(0.7))
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
                Label("Sperren", systemImage: "nosign")
            }
        }
        .popover(isPresented: $showEdit, arrowEdge: .trailing) {
            xpEditor
        }
    }

    private var tierBadgeSmall: some View {
        let rank = GamificationManager.rankInfo(forLevel: activity.activityLevel)
        return ZStack {
            Circle()
                .fill(tierColor.opacity(0.12))
                .frame(width: 28, height: 28)
            VStack(spacing: -1) {
                Text(rank.name.prefix(1).uppercased())
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(tierColor.opacity(0.8))
                Text(rank.roman)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tierColor)
            }
        }
    }

    private var tierColor: Color {
        switch activity.activityLevel {
        case 1...4:   return Color(red: 0.80, green: 0.52, blue: 0.25)  // Bronze
        case 5...8:   return Color(red: 0.65, green: 0.65, blue: 0.70)  // Silber
        case 9...12:  return Color(red: 1.00, green: 0.78, blue: 0.00)  // Gold
        case 13...16: return Color(red: 0.40, green: 0.82, blue: 1.00)  // Platin
        default:      return Color(red: 0.60, green: 0.40, blue: 1.00)  // Diamant
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
}
