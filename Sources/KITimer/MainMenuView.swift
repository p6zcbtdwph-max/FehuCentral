import SwiftUI

enum MenuPage: CaseIterable {
    case main, calendar, countdowns, projects, intervals, clipboard, settings

    var label: String {
        switch self {
        case .main:       return "Heute"
        case .calendar:   return "Kalender"
        case .countdowns: return "Countdown"
        case .projects:   return "Projekte"
        case .intervals:  return "Intervalle"
        case .clipboard:  return "Ablage"
        case .settings:   return "Einstellungen"
        }
    }

    var icon: String {
        switch self {
        case .main:       return "house"
        case .calendar:   return "calendar"
        case .countdowns: return "calendar.badge.clock"
        case .projects:   return "briefcase"
        case .intervals:  return "clock"
        case .clipboard:  return "doc.on.clipboard"
        case .settings:   return "gear"
        }
    }
}

struct MainMenuView: View {
    @EnvironmentObject var tm:      TimeManager
    @EnvironmentObject var clip:    ClipboardManager
    @EnvironmentObject var cal:     CalendarManager
    @EnvironmentObject var tracker: ProjectTracker
    @State private var page: MenuPage = .main

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(width: 320)
        .animation(.easeInOut(duration: 0.12), value: page)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            // Titel-Zeile
            HStack(alignment: .center) {
                if page != .main {
                    Button(action: { page = .main }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(page == .main ? "Fehu Central" : page.label)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: page == .main ? .leading : .center)

                // Settings-Icon rechts oben (immer sichtbar)
                Button(action: { page = page == .settings ? .main : .settings }) {
                    Image(systemName: "gear")
                        .font(.system(size: 13))
                        .foregroundStyle(page == .settings ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Tab-Navigation (nur auf Hauptseite)
            if page == .main {
                tabBar
                    .padding(.bottom, 10)
            }

            Divider()
        }
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach([MenuPage.calendar, .countdowns, .projects, .intervals, .clipboard], id: \.label) { p in
                    TabPill(icon: p.icon, label: p.label, isActive: page == p) {
                        page = p
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Inhalt je Seite

    @ViewBuilder
    private var content: some View {
        switch page {
        case .main:       mainContent
        case .clipboard:  ClipboardPage().environmentObject(clip)
        case .calendar:   CalendarPage().environmentObject(cal)
        case .countdowns: CountdownsPage().environmentObject(tm)
        case .projects:   ProjectsPage().environmentObject(tracker)
        case .intervals:  IntervalsPage().environmentObject(tm)
        case .settings:   SettingsView().environmentObject(tm)
        }
    }

    // MARK: - Hauptseite

    private var mainContent: some View {
        VStack(spacing: 0) {

            // Aktiver Kalender-Termin
            if let ev = cal.activeEvent {
                calendarBanner(ev)
                Divider()
            }

            // Aktives Intervall
            if let iv = tm.activeInterval {
                activeBanner(iv)
                Divider()
            }

            // Pomodoro
            PomodoroSection()
                .environmentObject(tm)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()

            // Fortschritts-Ringe
            HStack(spacing: 0) {
                CircleRingView(systemImage: "sun.max.fill",         progress: tm.dayProgress,   label: "Tag",   remainingText: tm.dayRemainingText)
                CircleRingView(systemImage: "calendar.badge.clock", progress: tm.weekProgress,  label: "Woche", remainingText: tm.weekRemainingText)
                CircleRingView(systemImage: "calendar",             progress: tm.monthProgress, label: "Monat", remainingText: tm.monthRemainingText)
                CircleRingView(systemImage: "arrow.circlepath",     progress: tm.yearProgress,  label: "Jahr",  remainingText: tm.yearRemainingText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 14)

            // Countdown-Ringe
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
                    .padding(.vertical, 12)
                }
            }

            Divider()

            // Footer
            HStack(spacing: 8) {
                // Laufendes Projekt
                if let p = tracker.activeProject {
                    Button(action: { page = .projects }) {
                        HStack(spacing: 4) {
                            Text(p.emoji).font(.system(size: 12))
                            Text(tracker.elapsed.hhmmss)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button("Beenden") { NSApp.terminate(nil) }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
    }

    // MARK: - Aktives Intervall Banner

    private func activeBanner(_ iv: TimerInterval) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(iv.name)
                    .font(.system(size: 12, weight: .semibold))
                Text(tm.intervalRemainingText(iv))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            CircularMiniProgress(progress: tm.intervalProgress(iv), color: .blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Kalender Banner

    private func calendarBanner(_ ev: CalendarEvent) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ev.calendarColor)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(ev.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(ev.timeRange)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            CircularMiniProgress(progress: ev.progress, color: ev.calendarColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { page = .calendar }
    }
}

// MARK: - Tab-Pill

struct TabPill: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                isActive
                    ? Color.accentColor.opacity(0.15)
                    : (hovered ? Color.secondary.opacity(0.1) : Color.clear)
            )
            .foregroundStyle(isActive ? Color.accentColor : .secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Mini-Kreisfortschritt für Banner

struct CircularMiniProgress: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 24, height: 24)
    }
}
