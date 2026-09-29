import SwiftUI
import EventKit

struct SettingsView: View {
    @EnvironmentObject var tm:  TimeManager
    @EnvironmentObject var cal: CalendarManager
    @EnvironmentObject var gam: GamificationManager
    var navigate: (MenuPage) -> Void = { _ in }
    @State private var tab: SettingsTab = .arbeitszeit

    enum SettingsTab: String, CaseIterable {
        case arbeitszeit = "Zeiten"
        case pomodoro    = "Pomodoro"
        case notify      = "Hinweise"
        case integrations = "Apps"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Werkzeuge-Sektion
            werkzeugSection
            Divider()

            // Tab-Leiste
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { t in
                    Button(action: { tab = t }) {
                        Text(t.rawValue)
                            .font(.system(size: 11, weight: tab == t ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                tab == t
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear
                            )
                            .foregroundStyle(tab == t ? Color.accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.secondary.opacity(0.06))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch tab {
                    case .arbeitszeit:    arbeitszeitTab
                    case .pomodoro:       pomodoroTab
                    case .notify:         notifyTab
                    case .integrations:   integrationsTab
                    }
                    Spacer().frame(height: 12)
                }
                .padding(.top, 10)
            }
        }
    }

    // MARK: - Werkzeuge

    private var werkzeugSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Werkzeuge".uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)

            HStack(spacing: 8) {
                NavCard(icon: "calendar", label: "Kalender") { navigate(.calendar) }
                NavCard(icon: "clock",    label: "Intervalle") { navigate(.intervals) }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Zeiten

    private var arbeitszeitTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Wochentage")
            pickerRow("Beginn", binding: Binding(get: { tm.startHour }, set: { tm.startHour = $0 }))
            pickerRow("Ende",   binding: Binding(get: { tm.endHour   }, set: { tm.endHour   = $0 }))

            Divider().padding(.vertical, 10)

            sectionLabel("Wochenende")
            toggleRow("Eigene Zeiten", binding: Binding(get: { tm.weekendEnabled }, set: { tm.weekendEnabled = $0 }))
            if tm.weekendEnabled {
                pickerRow("Beginn", binding: Binding(get: { tm.weekendStartHour }, set: { tm.weekendStartHour = $0 }))
                pickerRow("Ende",   binding: Binding(get: { tm.weekendEndHour   }, set: { tm.weekendEndHour   = $0 }))
            }
        }
    }

    // MARK: - Pomodoro

    private var pomodoroTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Timer")
            stepperRow("Fokusphase", value: Binding(get: { tm.pomodoroDuration     }, set: { tm.pomodoroDuration     = $0 }), unit: "min", range: 5...90, step: 5)
            stepperRow("Pause",      value: Binding(get: { tm.pomodoroRestDuration }, set: { tm.pomodoroRestDuration = $0 }), unit: "min", range: 1...30, step: 1)
        }
    }

    // MARK: - Benachrichtigungen

    private var notifyTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Vor Tagesende")
            toggleRow("Noch 2 Stunden",  binding: Binding(get: { tm.notify2h  }, set: { tm.notify2h  = $0 }))
            toggleRow("Noch 1 Stunde",   binding: Binding(get: { tm.notify1h  }, set: { tm.notify1h  = $0 }))
            toggleRow("Noch 30 Minuten", binding: Binding(get: { tm.notify30m }, set: { tm.notify30m = $0 }))
        }
    }

    // MARK: - Integrationen

    private var integrationsTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Kalender")

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("macOS Kalender")
                        .font(.system(size: 13))
                    Text(calStatusText)
                        .font(.system(size: 11))
                        .foregroundStyle(calStatusColor)
                }
                Spacer()
                calAccessButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if cal.authStatus == .fullAccess {
                Divider()
                HStack {
                    Text("\(cal.todayEvents.count) Termine heute geladen")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Neu laden") { cal.fetchToday() }
                        .font(.system(size: 11))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider().padding(.vertical, 10)

            sectionLabel("Gamification")
            stepperRow(
                "Mindest-Vorkommen",
                value: Binding(get: { gam.minimumOccurrences }, set: { gam.minimumOccurrences = $0 }),
                unit: "×", range: 5...10, step: 1
            )
            HStack {
                Text("Aktivitäten, die seltener vorkommen, werden ignoriert.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }

    private var calStatusText: String {
        switch cal.authStatus {
        case .fullAccess:      return "Zugriff erteilt"
        case .notDetermined:   return "Noch nicht gefragt"
        case .restricted:      return "Durch MDM eingeschränkt"
        default:               return "Kein Zugriff"
        }
    }

    private var calStatusColor: Color {
        switch cal.authStatus {
        case .fullAccess: return .green
        case .notDetermined: return .secondary
        default: return .red
        }
    }

    @ViewBuilder
    private var calAccessButton: some View {
        switch cal.authStatus {
        case .fullAccess:
            Label("Verbunden", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.green)
        case .notDetermined:
            Button("Zugriff erlauben") { cal.requestAccess() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        default:
            Button("Einstellungen") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
    }

    private func toggleRow(_ label: String, binding: Binding<Bool>) -> some View {
        HStack {
            Text(label).font(.system(size: 13))
            Spacer()
            Toggle("", isOn: binding).labelsHidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 4)
    }

    private func pickerRow(_ label: String, binding: Binding<Int>) -> some View {
        HStack {
            Text(label).font(.system(size: 13))
            Spacer()
            Picker("", selection: binding) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d:00 Uhr", h)).tag(h)
                }
            }
            .pickerStyle(.menu).frame(width: 110).labelsHidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 4)
    }

    private func stepperRow(_ label: String, value: Binding<Int>, unit: String, range: ClosedRange<Int>, step: Int) -> some View {
        HStack {
            Text(label).font(.system(size: 13))
            Spacer()
            Text("\(value.wrappedValue) \(unit)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
            Stepper("", value: value, in: range, step: step).labelsHidden()
        }
        .padding(.horizontal, 16).padding(.vertical, 4)
    }
}
