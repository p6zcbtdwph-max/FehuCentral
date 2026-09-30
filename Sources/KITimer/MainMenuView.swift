import SwiftUI
import AppKit

/// Setzt das unterliegende NSWindow auf fully opaque — verhindert den Frosted-Glass-Effekt
struct OpaqueWindowFix: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let win = v.window else { return }
            win.isOpaque = true
            win.backgroundColor = .windowBackgroundColor
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let win = nsView.window else { return }
            win.isOpaque = true
            win.backgroundColor = .windowBackgroundColor
        }
    }
}

enum MenuPage {
    case main, calendar, countdowns, intervals, clipboard, settings, gamification, pomodoro
}

struct MainMenuView: View {
    @EnvironmentObject var tm:   TimeManager
    @EnvironmentObject var clip: ClipboardManager
    @EnvironmentObject var cal:  CalendarManager
    @EnvironmentObject var gam:  GamificationManager
    @State private var page: MenuPage = .main

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            content
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
        .background(OpaqueWindowFix().frame(width: 0, height: 0))
        .animation(.easeInOut(duration: 0.12), value: page)
    }

    // MARK: - Obere Leiste

    private var topBar: some View {
        HStack(alignment: .center, spacing: 8) {
            if page != .main {
                Button(action: { page = .main }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(pageTitle)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: page == .main ? .leading : .center)

            if page == .main {
                Button(action: { page = .pomodoro }) {
                    Group {
                        if tm.pomodoroPhase != .idle {
                            HStack(spacing: 3) {
                                Text(tm.pomodoroPhase == .work ? "🍅" : "☕")
                                Text(tm.pomodoroDisplayText)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            }
                        } else {
                            Text("Pomodoro")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tm.pomodoroPhase != .idle ? Color.red.opacity(0.12) : Color.secondary.opacity(0.08))
                    .foregroundStyle(tm.pomodoroPhase != .idle ? Color.red : Color.secondary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: { page = .clipboard }) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Ablage")
            }

            Button(action: { page = page == .settings ? .main : .settings }) {
                Image(systemName: "gear")
                    .font(.system(size: 13))
                    .foregroundStyle(page == .settings ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var pageTitle: String {
        switch page {
        case .main:         return "Fehu Central"
        case .clipboard:    return "Ablage"
        case .calendar:     return "Kalender"
        case .countdowns:   return "Countdown"
        case .intervals:    return "Intervalle"
        case .settings:     return "Einstellungen"
        case .gamification: return "Aktivitäten"
        case .pomodoro:     return "Pomodoro"
        }
    }

    // MARK: - Inhalte

    @ViewBuilder
    private var content: some View {
        switch page {
        case .main:         mainContent
        case .clipboard:    ClipboardPage().environmentObject(clip)
        case .calendar:     CalendarPage().environmentObject(cal)
        case .countdowns:   CountdownsPage().environmentObject(tm)
        case .intervals:    IntervalsPage().environmentObject(tm)
        case .settings:     SettingsView(navigate: { page = $0 }).environmentObject(tm).environmentObject(cal).environmentObject(gam)
        case .gamification: GamificationPage().environmentObject(gam).environmentObject(cal)
        case .pomodoro:     pomodoroPage
        }
    }

    // MARK: - Hauptseite

    private var mainContent: some View {
        VStack(spacing: 0) {

            // Banner: laufender Kalendertermin
            if let ev = cal.activeEvent {
                calendarBanner(ev)
                Divider()
            }

            // Banner: aktives Intervall
            if let iv = tm.activeInterval {
                activeBanner(iv)
                Divider()
            }

            // Fortschritts-Ringe (kompakter)
            HStack(spacing: 0) {
                CircleRingView(systemImage: "sun.max.fill",         progress: tm.dayProgress,   label: "Tag",   remainingText: tm.dayRemainingText)
                CircleRingView(systemImage: "calendar.badge.clock", progress: tm.weekProgress,  label: "Woche", remainingText: tm.weekRemainingText,  daysRemaining: tm.weekDaysRemaining)
                CircleRingView(systemImage: "calendar",             progress: tm.monthProgress, label: "Monat", remainingText: tm.monthRemainingText, daysRemaining: tm.monthDaysRemaining)
                CircleRingView(systemImage: "arrow.circlepath",     progress: tm.yearProgress,  label: "Jahr",  remainingText: tm.yearRemainingText,  daysRemaining: tm.yearDaysRemaining)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            // Countdown-Kreise (kompakter)
            let upcoming = tm.countdowns.filter { $0.daysRemaining() >= 0 }
            if !upcoming.isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(upcoming) { cd in
                            CountdownCircleView(event: cd) { page = .countdowns }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
            }

            Divider()

            // Gamification-Strip
            if cal.authStatus == .fullAccess && !gam.activities.isEmpty {
                gamificationStrip
                Divider()
                dailyGoalRow
                Divider()
                topActivitiesSection
                Divider()
            }

            // Navigation
            VStack(spacing: 4) {
                NavCard(icon: "calendar", label: "Kalender") { page = .calendar }
                NavCard(icon: "clock",    label: "Intervalle") { page = .intervals }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Beenden") { NSApp.terminate(nil) }
                    .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Pomodoro-Seite

    private var pomodoroPage: some View {
        VStack(spacing: 0) {
            PomodoroSection()
                .environmentObject(tm)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            Spacer()
        }
    }

    // MARK: - Gamification-Strip

    private var gamificationStrip: some View {
        Button(action: { page = .gamification }) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Text(gam.rank.roman)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.yellow)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Level \(gam.overallLevel) · \(gam.rank.name)")
                            .font(.system(size: 11, weight: .semibold))
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text("🔥 \(gam.streak)")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.secondary.opacity(0.12))
                                .frame(height: 5)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.yellow.opacity(0.75))
                                .frame(width: geo.size.width * gam.overallProgress, height: 5)
                        }
                    }
                    .frame(height: 5)
                }

                Spacer()

                if let top = gam.activities.first {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(top.count)×")
                            .font(.system(size: 11, weight: .semibold))
                        Text(top.title)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 80)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tagesziel

    private var dailyGoalRow: some View {
        let reached = gam.dailyGoalReached
        return Button(action: { page = .gamification }) {
            HStack(spacing: 10) {
                Image(systemName: reached ? "checkmark.circle.fill" : "target")
                    .font(.system(size: 14))
                    .foregroundStyle(reached ? Color.green : Color.secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Tagesziel")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text("\(GamificationManager.xpText(gam.todayXP)) / \(GamificationManager.xpText(gam.dailyGoal)) XP")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(reached ? Color.green : Color.secondary)
                    }
                    XPBar(progress: gam.dailyGoalProgress,
                          color: reached ? .green : .accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Top-Aktivitäten

    private var topActivitiesSection: some View {
        let visible = Array(gam.activities
            .filter { $0.count >= gam.minimumOccurrences }
            .prefix(2))
        return VStack(spacing: 0) {
            HStack {
                Text("Top-Aktivitäten".uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { page = .gamification }) {
                    HStack(spacing: 2) {
                        Text("Alle")
                        Image(systemName: "chevron.right").imageScale(.small)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 2)

            ForEach(visible) { act in
                ActivityDetailRow(activity: act)
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Banner: Intervall

    private func activeBanner(_ iv: TimerInterval) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(Color.blue).frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(iv.name).font(.system(size: 12, weight: .semibold))
                Text(tm.intervalRemainingText(iv)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            CircularMiniProgress(progress: tm.intervalProgress(iv), color: .blue)
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { page = .intervals }
    }

    // MARK: - Banner: Kalender

    private func calendarBanner(_ ev: CalendarEvent) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(ev.calendarColor).frame(width: 3, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(ev.title).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Text(ev.timeRange).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            CircularMiniProgress(progress: ev.progress, color: ev.calendarColor)
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { page = .calendar }
    }
}

// MARK: - Nav-Karte

struct NavCard: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background(hovered ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.07))
            .foregroundStyle(hovered ? .primary : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Mini-Kreisfortschritt

struct CircularMiniProgress: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 24, height: 24)
    }
}
