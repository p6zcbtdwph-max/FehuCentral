import SwiftUI
import AppKit

/// Hält das Popover-Fenster und passt dessen Höhe exakt an den Inhalt an.
/// SwiftUI vergrößert das MenuBarExtra-Fenster für hohe Seiten, verkleinert es aber nicht wieder.
final class PopoverWindow {
    static let shared = PopoverWindow()
    weak var window: NSWindow?
    private var lastHeight: CGFloat = 0

    func attach(_ win: NSWindow) {
        win.isOpaque = true
        win.backgroundColor = .windowBackgroundColor
        window = win
        if lastHeight > 0 { resize(to: lastHeight) }
    }

    func resize(to height: CGFloat) {
        guard height > 40 else { return }
        lastHeight = height
        DispatchQueue.main.async { [weak self] in
            guard let win = self?.window else { return }
            let target = win.frameRect(forContentRect: NSRect(x: 0, y: 0, width: 320, height: height)).height
            var f = win.frame
            guard abs(f.height - target) > 0.5 else { return }
            f.origin.y += f.height - target   // obere Kante bleibt fest
            f.size.height = target
            win.setFrame(f, display: true, animate: false)
        }
    }
}

struct OpaqueWindowFix: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { if let win = v.window { PopoverWindow.shared.attach(win) } }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { if let win = nsView.window { PopoverWindow.shared.attach(win) } }
    }
}

enum MenuPage {
    case main, calendar, times, clipboard, settings, gamification, pomodoro
}

struct MainMenuView: View {
    @EnvironmentObject var tm:   TimeManager
    @EnvironmentObject var clip: ClipboardManager
    @EnvironmentObject var cal:  CalendarManager
    @EnvironmentObject var gam:  GamificationManager
    @EnvironmentObject var ai:   AICycleManager
    @State private var page: MenuPage = .main
    @State private var timesTab: TimesTab = .countdowns
    @State private var showLimitEdit = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            if page != .main {
                subHeader
                Divider()
            }
            content
        }
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { geo in
            Color.clear
                .onAppear { PopoverWindow.shared.resize(to: geo.size.height) }
                .onChange(of: geo.size.height) { _, h in PopoverWindow.shared.resize(to: h) }
        })
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(NSColor.windowBackgroundColor))
        .background(OpaqueWindowFix().frame(width: 0, height: 0))
        .animation(.easeInOut(duration: 0.12), value: page)
    }

    // MARK: - Obere Leiste (auf jeder Seite gleich)

    private var topBar: some View {
        HStack(alignment: .center, spacing: 2) {
            Button(action: { page = .main }) {
                Text("Fehu Central")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            pomodoroButton
            TopBarIcon(icon: "doc.on.clipboard", label: "Ablage",        active: page == .clipboard) { toggle(.clipboard) }
            TopBarIcon(icon: "hourglass",        label: "Countdown & Intervalle", active: page == .times) { toggle(.times) }
            TopBarIcon(icon: "gearshape",        label: "Einstellungen", active: page == .settings)  { toggle(.settings) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func toggle(_ target: MenuPage) {
        page = page == target ? .main : target
    }

    private var pomodoroButton: some View {
        let running = tm.pomodoroPhase != .idle
        let onPage  = page == .pomodoro
        return Button(action: { toggle(.pomodoro) }) {
            Group {
                if running {
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
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(running ? Color.red.opacity(onPage ? 0.22 : 0.12)
                                : (onPage ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.09)))
            .foregroundStyle(running ? Color.red : (onPage ? Color.accentColor : Color.secondary))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Pomodoro")
    }

    private var subHeader: some View {
        Button(action: { page = .main }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 10, weight: .semibold))
                Text(pageTitle)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var pageTitle: String {
        switch page {
        case .main:         return "Fehu Central"
        case .clipboard:    return "Ablage"
        case .calendar:     return "Kalender"
        case .times:        return "Countdown & Intervalle"
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
        case .times:        TimesPage(tab: $timesTab).environmentObject(tm).environmentObject(ai)
        case .settings:     SettingsView().environmentObject(tm).environmentObject(cal).environmentObject(gam)
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

            // Banner: KI-Sitzung (auf Wunsch statt Intervall) oder aktives Intervall
            if ai.enabled && ai.showSessionOnMain {
                sessionBanner
                Divider()
            } else if let iv = tm.activeInterval {
                activeBanner(iv)
                Divider()
            }

            // Fortschritts-Ringe: Zeit und Tagesziel
            HStack(spacing: 0) {
                CircleRingView(systemImage: "sun.max.fill",         progress: tm.dayProgress,   label: "Tag",   remainingText: tm.dayRemainingText)
                CircleRingView(systemImage: "calendar.badge.clock", progress: tm.weekProgress,  label: "Woche", remainingText: tm.weekRemainingText,  daysRemaining: tm.weekDaysRemaining)
                CircleRingView(systemImage: "calendar",             progress: tm.monthProgress, label: "Monat", remainingText: tm.monthRemainingText, daysRemaining: tm.monthDaysRemaining)
                CircleRingView(systemImage: "arrow.circlepath",     progress: tm.yearProgress,  label: "Jahr",  remainingText: tm.yearRemainingText,  daysRemaining: tm.yearDaysRemaining)
                if hasGamification {
                    CircleRingView(
                        systemImage: "target",
                        progress: gam.dailyGoalProgress,
                        label: "Ziel",
                        remainingText: "Tagesziel: \(GamificationManager.xpText(gam.todayXP)) von \(GamificationManager.xpText(gam.dailyGoal)) XP",
                        subText: "\(GamificationManager.xpText(gam.todayXP))/\(GamificationManager.xpText(gam.dailyGoal))",
                        color: gam.dailyGoalReached ? .green : .accentColor
                    )
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)

            // Countdown-Kreise
            let upcoming = tm.countdowns.filter { $0.daysRemaining() >= 0 }
            if !upcoming.isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(upcoming) { cd in
                            CountdownCircleView(event: cd) { timesTab = .countdowns; page = .times }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
            }

            // KI-Limit: Verbrauch gegen Plan
            if ai.enabled {
                Divider()
                limitRow
            }

            // Level: Klick öffnet alle Aktivitäten
            if hasGamification {
                Divider()
                gamificationStrip
            }
        }
    }

    private var hasGamification: Bool {
        cal.authStatus == .fullAccess && !gam.activities.isEmpty
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - KI-Sitzung und Limit

    private var sessionBanner: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(Color.purple).frame(width: 3, height: 30)
            if ai.sessionActive, let end = ai.sessionEnd {
                VStack(alignment: .leading, spacing: 1) {
                    Text("KI-Sitzung").font(.system(size: 12, weight: .semibold))
                    Text("Reset in \(ai.sessionRemainingText) · \(end.formatted(.dateTime.hour().minute())) Uhr")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                CircularMiniProgress(progress: ai.sessionProgress, color: .purple, showRemaining: true)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text("KI-Sitzung").font(.system(size: 12, weight: .semibold))
                    Text(ai.sessionEnd == nil ? "Nicht gestartet" : "Abgelaufen")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Starten (\(ai.sessionHours) h)") { ai.startSession() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { timesTab = .aiCycles; page = .times }
    }

    private var limitRow: some View {
        Button(action: { showLimitEdit = true }) {
            HStack(spacing: 10) {
                Image(systemName: "speedometer")
                    .font(.system(size: 14))
                    .foregroundStyle(ai.statusColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("KI-Limit").font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text("\(AICycleManager.pct(ai.usedNow)) verbraucht · \(AICycleManager.pct(ai.freePercent)) frei")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    LimitBar(used: ai.usedNow, target: ai.targetPercent, color: ai.statusColor)
                    Text("\(ai.statusText) · Reset \(ai.weekEnd.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
                        .font(.system(size: 9)).foregroundStyle(ai.statusColor)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showLimitEdit, arrowEdge: .bottom) { limitEditor }
    }

    private var limitEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Verbrauch eintragen").font(.system(size: 12, weight: .semibold))
                Spacer()
                Text(AICycleManager.pct(ai.usedNow))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            Slider(value: Binding(get: { ai.usedNow }, set: { ai.setUsed($0.rounded()) }), in: 0...100)
            Text("\(ai.statusText). Pro Tag sind \(AICycleManager.pct(ai.perDayPercent)) vorgesehen.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Details") {
                showLimitEdit = false
                timesTab = .aiCycles
                page = .times
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(14)
        .frame(width: 240)
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
            CircularMiniProgress(progress: tm.intervalProgress(iv), color: .blue, showRemaining: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { timesTab = .intervals; page = .times }
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
            CircularMiniProgress(progress: ev.progress, color: ev.calendarColor, showRemaining: true)
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
    var showRemaining = false

    private var remainingPercent: Int { max(0, min(100, Int(((1 - progress) * 100).rounded()))) }

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: showRemaining ? 3.5 : 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: showRemaining ? 3.5 : 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showRemaining {
                VStack(spacing: 0) {
                    Text("\(remainingPercent)%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                    Text("übrig")
                        .font(.system(size: 6))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: showRemaining ? 40 : 24, height: showRemaining ? 40 : 24)
    }
}

// MARK: - Icon-Button der Kopfleiste

struct TopBarIcon: View {
    let icon: String
    let label: String
    let active: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(active ? Color.accentColor : (hovered ? Color.primary : Color.secondary))
                .frame(width: 26, height: 26)
                .background(active ? Color.accentColor.opacity(0.14)
                                   : (hovered ? Color.secondary.opacity(0.1) : Color.clear))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(label)
    }
}
