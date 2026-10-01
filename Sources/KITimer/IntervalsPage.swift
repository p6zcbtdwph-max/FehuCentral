import SwiftUI

struct IntervalsPage: View {
    @EnvironmentObject var tm: TimeManager
    @State private var editingInterval: TimerInterval? = nil  // nil = neu
    @State private var showEditor = false

    var body: some View {
        VStack(spacing: 0) {
            if showEditor {
                IntervalEditorView(
                    interval: editingInterval ?? TimerInterval(),
                    isNew: editingInterval == nil,
                    onSave: { iv in
                        if editingInterval == nil { tm.addInterval(iv) }
                        else { tm.updateInterval(iv) }
                        showEditor = false
                    },
                    onCancel: { showEditor = false }
                )
            } else {
                listView
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            // Liste
            if tm.intervals.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.plus")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Noch keine Intervalle")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button("Erstes Intervall anlegen") {
                        editingInterval = nil
                        showEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(tm.intervals) { iv in
                            IntervalRowView(
                                interval: iv,
                                status: tm.intervalStatus(iv),
                                progress: tm.intervalProgress(iv),
                                remainingText: tm.intervalRemainingText(iv)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingInterval = iv
                                showEditor = true
                            }
                            .overlay(alignment: .trailing) {
                                Button(action: { tm.deleteInterval(id: iv.id) }) {
                                    Image(systemName: "trash")
                                        .imageScale(.small)
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 300)
            }

            Divider()

            // Footer: neu anlegen
            Button(action: { editingInterval = nil; showEditor = true }) {
                Label("Intervall hinzufügen", systemImage: "plus.circle.fill")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Einzelne Zeile
struct IntervalRowView: View {
    let interval: TimerInterval
    let status: TimeManager.IntervalStatus
    let progress: Double
    let remainingText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                Text(interval.name)
                    .font(.system(size: 13, weight: status == .active ? .semibold : .regular))
                Text("· \(interval.durationText)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(interval.displayRange)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 28) // Platz für Trash-Button
            }

            if status == .active {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue.gradient)
                            .frame(width: max(0, (geo.size.width - 28) * progress), height: 5)
                    }
                }
                .frame(height: 5)
                .padding(.leading, 14)

                Text("\(remainingText) · \(max(0, min(100, Int(((1 - progress) * 100).rounded()))))% übrig")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 14)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .opacity(status == .done ? 0.4 : 1.0)
    }

    private var dotColor: Color {
        switch status {
        case .active:   return .blue
        case .done:     return .secondary
        case .upcoming: return Color.secondary.opacity(0.5)
        }
    }
}

// MARK: - Editor
struct IntervalEditorView: View {
    @State var interval: TimerInterval
    let isNew: Bool
    let onSave: (TimerInterval) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("NAME".uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("z.B. Deep Work", text: $interval.name)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            // Zeiten
            VStack(spacing: 4) {
                timeRow("Von", hour: $interval.startHour, minute: $interval.startMinute)
                timeRow("Bis", hour: $interval.endHour,   minute: $interval.endMinute)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Dauer-Anzeige
            if interval.durationMinutes > 0 {
                HStack {
                    Spacer()
                    Text("Dauer: \(interval.durationText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Divider()

            // Buttons
            HStack {
                Button("Abbrechen", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(isNew ? "Hinzufügen" : "Speichern") {
                    onSave(interval)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(interval.name.trimmingCharacters(in: .whitespaces).isEmpty
                          || interval.durationMinutes <= 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func timeRow(_ label: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .frame(width: 28, alignment: .leading)
            Picker("", selection: hour) {
                ForEach(0..<24, id: \.self) { h in
                    Text(String(format: "%02d", h)).tag(h)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 64)
            .labelsHidden()

            Text(":")
                .foregroundStyle(.secondary)

            Picker("", selection: minute) {
                ForEach([0, 15, 30, 45], id: \.self) { m in
                    Text(String(format: "%02d", m)).tag(m)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 64)
            .labelsHidden()

            Text("Uhr")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
