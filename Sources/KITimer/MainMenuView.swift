import SwiftUI

enum MenuPage { case main, countdowns, calendar, projects, intervals, clipboard, settings }

struct MainMenuView: View {
    @EnvironmentObject var tm:      TimeManager
    @EnvironmentObject var clip:    ClipboardManager
    @EnvironmentObject var cal:     CalendarManager
    @EnvironmentObject var tracker: ProjectTracker
    @State private var page: MenuPage = .main

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 300)
        .animation(.easeInOut(duration: 0.15), value: page)
    }

    // MARK: - Header (immer sichtbar)
    private var header: some View {
        HStack {
            // Zurück-Pfeil
            if page != .main {
                Button(action: { page = .main }) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left").imageScale(.small)
                        Text("Zurück")
                    }
                    .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            // Titel
            VStack(alignment: page == .main ? .leading : .center, spacing: 1) {
                Text(pageTitle)
                    .font(.headline)
                if page == .main {
                    Text(tm.now, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: page == .main ? .leading : .center)

            // Rechte Buttons (nur Hauptseite)
            if page == .main {
                HStack(spacing: 10) {
                    Button(action: { page = .clipboard }) {
                        Image(systemName: "doc.on.clipboard").imageScale(.medium)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Zwischenablage")

                    Button(action: { page = .calendar }) {
                        Image(systemName: "calendar").imageScale(.medium)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Kalender")

                    Button(action: { page = .countdowns }) {
                        Image(systemName: "calendar.badge.clock").imageScale(.medium)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Countdowns")

                    Button(action: { page = .projects }) {
                        Image(systemName: "folder.badge.clock").imageScale(.medium)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Projekte")

                    Button(action: { page = .intervals }) {
                        Image(systemName: "clock.badge.checkmark").imageScale(.medium)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Intervalle")

                    Button(action: { page = .settings }) {
                        Image(systemName: "gear").imageScale(.medium)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help("Einstellungen")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var pageTitle: String {
        switch page {
        case .main:       return "Fehu Central"
        case .clipboard:  return "Zwischenablage"
        case .calendar:   return "Kalender"
        case .countdowns: return "Countdowns"
        case .projects:   return "Projekte"
        case .intervals:  return "Intervalle"
        case .settings:   return "Einstellungen"
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

            // Aktives Intervall (Banner, wenn vorhanden)
            if let iv = tm.activeInterval {
                activeBanner(iv)
                Divider()
            }

            // Pomodoro
            PomodoroSection()
                .environmentObject(tm)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            // Fortschritts-Ringe
            HStack(spacing: 0) {
                CircleRingView(systemImage: "sun.max.fill",        progress: tm.dayProgress,   label: "Tag",   remainingText: tm.dayRemainingText)
                CircleRingView(systemImage: "calendar.badge.clock", progress: tm.weekProgress,  label: "Woche", remainingText: tm.weekRemainingText)
                CircleRingView(systemImage: "calendar",             progress: tm.monthProgress, label: "Monat", remainingText: tm.monthRemainingText)
                CircleRingView(systemImage: "arrow.circlepath",     progress: tm.yearProgress,  label: "Jahr",  remainingText: tm.yearRemainingText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 14)

            // Countdown-Ringe (wenn vorhanden)
            if !tm.countdowns.filter({ $0.daysRemaining() >= 0 }).isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(tm.countdowns.filter { $0.daysRemaining() >= 0 }) { cd in
                            CountdownCircleView(event: cd) { page = .countdowns }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }

            // Aktiver Kalender-Termin
            if let ev = cal.activeEvent {
                Divider()
                calendarBanner(ev)
            }

            Divider()

            // Footer
            HStack {
                Text(tm.now, style: .time)
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                Spacer()
                // Laufendes Projekt anzeigen
                if let p = tracker.activeProject {
                    Button(action: { page = .projects }) {
                        HStack(spacing: 3) {
                            Text(p.emoji).font(.system(size: 11))
                            Text(tracker.elapsed.hhmmss)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                Button("Beenden") { NSApp.terminate(nil) }
                    .font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Aktiver Intervall Banner
    private func activeBanner(_ iv: TimerInterval) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .imageScale(.small)
                        .foregroundStyle(.blue)
                    Text(iv.name)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(tm.intervalRemainingText(iv))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mini-Progress
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(tm.intervalProgress(iv) * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.15)).frame(height: 5)
                        RoundedRectangle(cornerRadius: 2).fill(Color.blue).frame(width: geo.size.width * tm.intervalProgress(iv), height: 5)
                    }
                }
                .frame(width: 60, height: 5)
            }
            .frame(width: 60, height: 30)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Kalender-Banner
    private func calendarBanner(_ ev: CalendarEvent) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(ev.calendarColor)
                .frame(width: 3, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text(ev.title)
                        .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                }
                Text(ev.timeRange)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }

            Spacer()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.15)).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(ev.calendarColor)
                        .frame(width: geo.size.width * ev.progress, height: 4)
                }
            }
            .frame(width: 50, height: 4)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { page = .calendar }
    }
}
