import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var tm: TimeManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Wochentage ──────────────────────────────────
                sectionLabel("Wochentage")
                pickerRow("Tagesbeginn", binding: Binding(get: { tm.startHour }, set: { tm.startHour = $0 }))
                pickerRow("Tagesende",   binding: Binding(get: { tm.endHour },   set: { tm.endHour   = $0 }))

                Divider().padding(.vertical, 10)

                // ── Wochenende ──────────────────────────────────
                sectionLabel("Wochenende")
                toggleRow("Eigene Zeiten", binding: Binding(get: { tm.weekendEnabled }, set: { tm.weekendEnabled = $0 }))
                if tm.weekendEnabled {
                    pickerRow("Beginn (Sa/So)", binding: Binding(get: { tm.weekendStartHour }, set: { tm.weekendStartHour = $0 }))
                    pickerRow("Ende (Sa/So)",   binding: Binding(get: { tm.weekendEndHour },   set: { tm.weekendEndHour   = $0 }))
                }

                Divider().padding(.vertical, 10)

                // ── Pomodoro ────────────────────────────────────
                sectionLabel("Pomodoro")
                stepperRow("Fokusphase", value: Binding(get: { tm.pomodoroDuration },     set: { tm.pomodoroDuration     = $0 }), unit: "min", range: 5...90,  step: 5)
                stepperRow("Pause",      value: Binding(get: { tm.pomodoroRestDuration }, set: { tm.pomodoroRestDuration = $0 }), unit: "min", range: 1...30,  step: 1)

                Divider().padding(.vertical, 10)

                // ── Benachrichtigungen ──────────────────────────
                sectionLabel("Benachrichtigungen")
                toggleRow("Noch 2 Stunden",   binding: Binding(get: { tm.notify2h  }, set: { tm.notify2h  = $0 }))
                toggleRow("Noch 1 Stunde",    binding: Binding(get: { tm.notify1h  }, set: { tm.notify1h  = $0 }))
                toggleRow("Noch 30 Minuten",  binding: Binding(get: { tm.notify30m }, set: { tm.notify30m = $0 }))

                Spacer().frame(height: 12)
            }
            .padding(.top, 8)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
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
            .pickerStyle(.menu)
            .frame(width: 110)
            .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }

    private func stepperRow(_ label: String, value: Binding<Int>, unit: String, range: ClosedRange<Int>, step: Int) -> some View {
        HStack {
            Text(label).font(.system(size: 13))
            Spacer()
            Text("\(value.wrappedValue) \(unit)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .trailing)
            Stepper("", value: value, in: range, step: step)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
    }
}
