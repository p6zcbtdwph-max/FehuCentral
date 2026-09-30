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
                    Text("\(GamificationManager.xpText(gam.totalXP)) XP")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                    if let next = gam.rank.nextRankLevel {
                        Text("→ \(GamificationManager.rankInfo(forLevel: next).name) ab Level \(next)")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    } else if gam.overallLevel < 20 {
                        EmptyView()
                    } else {
                        Text("Level \(gam.overallLevel + 1) in \(GamificationManager.xpText(GamificationManager.xpNeeded(toReach: gam.overallLevel + 1) - gam.totalXP)) XP")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
            }

            // Tagesziel
            VStack(spacing: 4) {
                HStack {
                    Text("TAGESZIEL")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    Spacer()
                    if gam.dailyGoalReached {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10)).foregroundStyle(.green)
                    }
                    Text("\(GamificationManager.xpText(gam.todayXP)) / \(GamificationManager.xpText(gam.dailyGoal)) XP")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(gam.dailyGoalReached ? .green : .primary)
                }
                XPBar(progress: gam.dailyGoalProgress,
                      color: gam.dailyGoalReached ? .green : .accentColor, height: 8)
                HStack {
                    Text("Woche \(GamificationManager.xpText(gam.weekXP)) XP")
                    Spacer()
                    Text("Monat \(GamificationManager.xpText(gam.monthXP)) XP")
                }
                .font(.system(size: 10)).foregroundStyle(.secondary)
            }

            // Stat-Chips
            HStack(spacing: 8) {
                statChip("\(gam.activities.count)", "Aktivitäten")
                statChip("\(gam.activities.reduce(0) { $0 + $1.count })", "Termine")
                statChip(formattedTotalTime, "Gesamt-Zeit")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var formattedTotalTime: String {
        let total = gam.activities.reduce(0) { $0 + $1.totalMinutes }
        let h = total / 60; let m = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    // MARK: - Aktivitätenliste

    private var activityList: some View {
        let filtered = gam.activities.filter { $0.count >= gam.minimumOccurrences }
        return VStack(spacing: 0) {
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

            ForEach(filtered) { activity in
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

// MARK: - Fortschrittsbalken

struct XPBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.secondary.opacity(0.12))
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color.opacity(0.85))
                    .frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Einzelne Aktivitätszeile

struct ActivityDetailRow: View {
    let activity: ActivityStat
    @EnvironmentObject var gam: GamificationManager
    @State private var hovered    = false
    @State private var showEdit   = false
    @State private var editXPH    = 100
    @State private var editTitle  = ""
    @State private var showMerge  = false

    var body: some View {
        HStack(spacing: 8) {
            tierBadgeSmall

            // Titel + Statistik
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(activity.count)×")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.tertiary)
                    Text(activity.formattedTime)
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }

            Spacer()

            // XP/h — Spalte, klickbar
            Button(action: { editXPH = activity.xpPerHour; editTitle = activity.title; showMerge = false; showEdit = true }) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(GamificationManager.xpText(activity.xpPerHour)) XP/h")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                    Text("+\(GamificationManager.xpText(activity.earnedXP)) XP")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow.opacity(0.85))
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showEdit, arrowEdge: .trailing) {
                xpEditor
            }

            // Blacklist-Button
            Button(action: { gam.addToBlacklist(activity.title) }) {
                Image(systemName: "nosign")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(hovered ? 0.6 : 0.25))
            }
            .buttonStyle(.plain)
            .help("Sperren")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(hovered ? Color.secondary.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { editXPH = activity.xpPerHour; editTitle = activity.title; showMerge = false; showEdit = true }
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
        case 1...4:   return Color(red: 0.80, green: 0.52, blue: 0.25)
        case 5...8:   return Color(red: 0.65, green: 0.65, blue: 0.70)
        case 9...12:  return Color(red: 1.00, green: 0.78, blue: 0.00)
        case 13...16: return Color(red: 0.40, green: 0.82, blue: 1.00)
        default:      return Color(red: 0.60, green: 0.40, blue: 1.00)
        }
    }

    private var xpEditor: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Umbenennen
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                TextField("Aktivitätsname", text: $editTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }

            // XP/h
            VStack(alignment: .leading, spacing: 6) {
                Text("XP pro Stunde")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                HStack {
                    Text("\(GamificationManager.xpText(editXPH)) XP/h")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .frame(width: 80)
                    Stepper("", value: $editXPH, in: 10...500, step: 10)
                        .labelsHidden()
                }
            }

            // Zusammenlegen
            VStack(alignment: .leading, spacing: 6) {
                Button(action: { showMerge.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: showMerge ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                        Text("Zusammenlegen mit…")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)

                if showMerge {
                    let others = gam.activities.filter { $0.title != activity.title }
                    if others.isEmpty {
                        Text("Keine weiteren Aktivitäten")
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(others) { other in
                                    Button(action: {
                                        gam.mergeActivities(sources: [other.title], into: activity.title)
                                        showEdit = false
                                    }) {
                                        HStack {
                                            Text(other.title)
                                                .font(.system(size: 11))
                                                .lineLimit(1)
                                            Spacer()
                                            Text("\(other.count)×")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            // Aktionsbuttons
            HStack(spacing: 8) {
                Button("Speichern") {
                    let trimmed = editTitle.trimmingCharacters(in: .whitespaces)
                    let finalTitle = trimmed.isEmpty ? activity.title : trimmed
                    if finalTitle != activity.title {
                        gam.renameActivity(from: activity.title, to: finalTitle)
                    }
                    gam.setXPPerHour(editXPH, for: finalTitle)
                    showEdit = false
                }
                .buttonStyle(.borderedProminent).controlSize(.small)
                .disabled(editTitle.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Sperren") {
                    gam.addToBlacklist(activity.title)
                    showEdit = false
                }
                .buttonStyle(.bordered).controlSize(.small)
                .foregroundStyle(.red)
            }
        }
        .padding(14)
        .frame(width: 240)
    }
}
