import SwiftUI

enum MenuPage { case main, intervals, clipboard, settings }

struct MainMenuView: View {
    @EnvironmentObject var tm:   TimeManager
    @EnvironmentObject var clip: ClipboardManager
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
                HStack(spacing: 12) {
                    Button(action: { page = .clipboard }) {
                        Image(systemName: "doc.on.clipboard")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Zwischenablage")

                    Button(action: { page = .intervals }) {
                        Image(systemName: "clock.badge.checkmark")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Intervalle")

                    Button(action: { page = .settings }) {
                        Image(systemName: "gear")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Einstellungen")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var pageTitle: String {
        switch page {
        case .main:      return "Productivity Timer"
        case .clipboard: return "Zwischenablage"
        case .intervals: return "Intervalle"
        case .settings:  return "Einstellungen"
        }
    }

    // MARK: - Inhalt je Seite
    @ViewBuilder
    private var content: some View {
        switch page {
        case .main:      mainContent
        case .clipboard: ClipboardPage().environmentObject(clip)
        case .intervals: IntervalsPage().environmentObject(tm)
        case .settings:  SettingsView().environmentObject(tm)
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

            // Fortschrittsbalken
            VStack(spacing: 12) {
                ProgressRow(label: "Tag",   systemImage: "sun.max.fill",        progress: tm.dayProgress,   remainingText: tm.dayRemainingText)
                ProgressRow(label: "Woche", systemImage: "calendar.badge.clock", progress: tm.weekProgress,  remainingText: tm.weekRemainingText)
                ProgressRow(label: "Monat", systemImage: "calendar",             progress: tm.monthProgress, remainingText: tm.monthRemainingText)
                ProgressRow(label: "Jahr",  systemImage: "arrow.circlepath",     progress: tm.yearProgress,  remainingText: tm.yearRemainingText)
            }
            .padding(16)

            Divider()

            // Footer
            HStack {
                Text(tm.now, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Button("Beenden") { NSApp.terminate(nil) }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
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
}
