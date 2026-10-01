import SwiftUI
import EventKit

struct SettingsView: View {
    @EnvironmentObject var tm:  TimeManager
    @EnvironmentObject var cal: CalendarManager
    @EnvironmentObject var gam: GamificationManager
    var navigate: (MenuPage) -> Void = { _ in }
    @State private var tab: SettingsTab = .arbeitszeit

    enum SettingsTab: String, CaseIterable {
        case arbeitszeit  = "Zeiten"
        case pomodoro     = "Pomodoro"
        case notify       = "Hinweise"
        case integrations = "Apps"
    }

    var body: some View {
        VStack(spacing: 0) {
            werkzeugSection
            Divider()

            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { t in
                    Button(action: { tab = t }) {
                        Text(t.rawValue)
                            .font(.system(size: 11, weight: tab == t ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(tab == t ? Color.accentColor.opacity(0.12) : Color.clear)
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
                    case .arbeitszeit:  arbeitszeitTab
                    case .pomodoro:     pomodoroTab
                    case .notify:       notifyTab
                    case .integrations: integrationsTab
                    }
                    Spacer().frame(height: 12)
                }
                .padding(.top, 10)
            }
            .frame(maxHeight: 420)

            Divider()
            HStack {
                Spacer()
                Button("Fehu Central beenden") { NSApp.terminate(nil) }
                    .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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

            NavCard(icon: "calendar.badge.clock", label: "Countdown") { navigate(.countdowns) }
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

            // Zeitraum
            HStack {
                Text("Aktivitäten ab")
                    .font(.system(size: 13))
                Spacer()
                DatePicker(
                    "",
                    selection: Binding(
                        get: { gam.historyStartDate },
                        set: { gam.historyStartDate = $0 }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            stepperRow(
                "Mindest-Vorkommen",
                value: Binding(get: { gam.minimumOccurrences }, set: { gam.minimumOccurrences = $0 }),
                unit: "×", range: 1...20, step: 1
            )
            Text("Aktivitäten mit weniger Einträgen werden ignoriert. Auf 1 setzen zum Testen.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // Tagesziel
            Divider().padding(.vertical, 10)
            sectionLabel("Tagesziel")
            toggleRow("Automatisch anpassen", binding: Binding(get: { gam.goalAuto }, set: { gam.goalAuto = $0 }))
            if gam.goalAuto {
                Text("Aktuell \(GamificationManager.xpText(gam.dailyGoal)) XP: Schnitt der letzten 7 Tage mal 1,2, mindestens 1 XP.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            } else {
                HStack {
                    Text("Ziel pro Tag").font(.system(size: 13))
                    Spacer()
                    Text("\(GamificationManager.xpText(gam.goalManualXP)) XP")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                    Stepper("", value: Binding(get: { gam.goalManualXP }, set: { gam.goalManualXP = $0 }),
                            in: 50...2000, step: 50).labelsHidden()
                }
                .padding(.horizontal, 16).padding(.vertical, 4)
            }

            // Kalender-Filter
            if cal.authStatus == .fullAccess && !cal.availableCalendars.isEmpty {
                Divider().padding(.vertical, 10)
                sectionLabel("Kalender-Filter")
                Text("Welche Kalender sollen für Aktivitäten ausgewertet werden?")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                ForEach(cal.availableCalendars, id: \.calendarIdentifier) { calendar in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(cgColor: calendar.cgColor))
                            .frame(width: 8, height: 8)
                        Text(calendar.title)
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { !gam.excludedCalendarIDs.contains(calendar.calendarIdentifier) },
                            set: { include in
                                if include {
                                    gam.excludedCalendarIDs.remove(calendar.calendarIdentifier)
                                } else {
                                    gam.excludedCalendarIDs.insert(calendar.calendarIdentifier)
                                }
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var calStatusText: String {
        switch cal.authStatus {
        case .fullAccess:    return "Zugriff erteilt"
        case .notDetermined: return "Noch nicht gefragt"
        case .restricted:    return "Durch MDM eingeschränkt"
        default:             return "Kein Zugriff"
        }
    }

    private var calStatusColor: Color {
        switch cal.authStatus {
        case .fullAccess:    return .green
        case .notDetermined: return .secondary
        default:             return .red
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
