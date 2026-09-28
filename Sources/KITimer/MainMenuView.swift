import SwiftUI

enum MenuPage {
    case main, calendar, countdowns, projects, intervals, clipboard, settings
}

struct MainMenuView: View {
    @EnvironmentObject var tm:      TimeManager
    @EnvironmentObject var clip:    ClipboardManager
    @EnvironmentObject var cal:     CalendarManager
    @EnvironmentObject var tracker: ProjectTracker
    @State private var page: MenuPage = .main

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            content
        }
        .frame(width: 320)
        .animation(.easeInOut(duration: 0.12), value: page == .main)
    }

    // MARK: - Obere Leiste (immer sichtbar)

    private var topBar: some View {
        HStack(alignment: .center) {
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
        case .main:       return "Fehu Central"
        case .clipboard:  return "Ablage"
        case .calendar:   return "Kalender"
        case .countdowns: return "Countdown"
        case .projects:   return "Projekte"
        case .intervals:  return "Intervalle"
        case .settings:   return "Einstellungen"
        }
    }

    // MARK: - Inhalte

    @ViewBuilder
    private var content: some View {
        switch page {
        case .main:       mainContent
        case .clipboard:  ClipboardPage().environmentObject(clip)
        case .calendar:   CalendarPage().environmentObject(cal)
        case .countdowns: CountdownsPage().environmentObject(tm)
        case .projects:   ProjectsPage().environmentObject(tracker)
        case .intervals:  IntervalsPage().environmentObject(tm)
        case .settings:   SettingsView(navigate: { page = $0 }).environmentObject(tm).environmentObject(cal)
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

            // Pomodoro
            PomodoroSection()
                .environmentObject(tm)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)

            Divider()

            // Fortschritts-Ringe
            HStack(spacing: 0) {
                CircleRingView(systemImage: "sun.max.fill",         progress: tm.dayProgress,   label: "Tag",   remainingText: tm.dayRemainingText)
                CircleRingView(systemImage: "calendar.badge.clock", progress: tm.weekProgress,  label: "Woche", remainingText: tm.weekRemainingText)
                CircleRingView(systemImage: "calendar",             progress: tm.monthProgress, label: "Monat", remainingText: tm.monthRemainingText)
                CircleRingView(systemImage: "arrow.circlepath",     progress: tm.yearProgress,  label: "Jahr",  remainingText: tm.yearRemainingText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)

            // Countdown-Kreise
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
                    .padding(.vertical, 10)
                }
            }

            Divider()

            // Inline-Projekte
            miniProjectsSection

            Divider()

            // 2-Spalten-Navigation
            navGrid

            Divider()

            // Footer
            HStack {
                if let p = tracker.activeProject {
                    Button(action: { page = .projects }) {
                        HStack(spacing: 4) {
                            Text(p.emoji).font(.system(size: 11))
                            Text(tracker.elapsed.hhmmss)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button("Beenden") { NSApp.terminate(nil) }
                    .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - 2-Spalten-Nav

    private var navGrid: some View {
        let items: [(icon: String, label: String, dest: MenuPage)] = [
            ("calendar.badge.clock", "Countdown", .countdowns),
            ("doc.on.clipboard",     "Ablage",    .clipboard),
        ]

        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 6
        ) {
            ForEach(items, id: \.label) { item in
                NavCard(icon: item.icon, label: item.label) { page = item.dest }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Mini-Projekte

    private var miniProjectsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Projekte".uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { page = .projects }) {
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
            .padding(.bottom, 4)

            if tracker.projects.isEmpty {
                Button(action: { page = .projects }) {
                    Label("Erstes Projekt anlegen", systemImage: "plus.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            } else {
                ForEach(tracker.projects.prefix(3)) { project in
                    MiniProjectRow(project: project)
                        .environmentObject(tracker)
                }
            }
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

// MARK: - Mini-Projektzeile

struct MiniProjectRow: View {
    let project: Project
    @EnvironmentObject var tracker: ProjectTracker
    @State private var hovered = false

    private var isActive: Bool { tracker.activeProject?.id == project.id }

    var body: some View {
        Button(action: { tracker.toggle(project) }) {
            HStack(spacing: 10) {
                Text(project.emoji).font(.system(size: 16))

                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    Text(isActive ? tracker.elapsed.hhmmss : tracker.todayDuration(for: project).hhmm)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(isActive ? Color.green : Color.secondary.opacity(0.5))
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(isActive ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                        .frame(width: 26, height: 26)
                    Image(systemName: isActive ? "stop.fill" : "play.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(isActive ? .green : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                isActive
                    ? Color.green.opacity(0.05)
                    : (hovered ? Color.secondary.opacity(0.05) : Color.clear)
            )
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
