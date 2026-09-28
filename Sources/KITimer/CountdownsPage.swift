import SwiftUI

struct CountdownsPage: View {
    @EnvironmentObject var tm: TimeManager
    @State private var editingEvent: CountdownEvent? = nil
    @State private var showEditor = false

    var body: some View {
        VStack(spacing: 0) {
            if showEditor {
                CountdownEditorView(
                    event: editingEvent ?? CountdownEvent(),
                    isNew: editingEvent == nil,
                    onSave: { ev in
                        if editingEvent == nil { tm.addCountdown(ev) }
                        else { tm.updateCountdown(ev) }
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
            if tm.countdowns.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Noch keine Countdowns")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Button("Ersten Countdown anlegen") {
                        editingEvent = nil
                        showEditor = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(tm.countdowns) { ev in
                            CountdownRow(event: ev)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingEvent = ev
                                    showEditor = true
                                }
                                .overlay(alignment: .trailing) {
                                    Button(action: { tm.deleteCountdown(id: ev.id) }) {
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
                .frame(maxHeight: 280)
            }

            Divider()

            Button(action: { editingEvent = nil; showEditor = true }) {
                Label("Countdown hinzufügen", systemImage: "plus")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Einzelne Zeile

struct CountdownRow: View {
    let event: CountdownEvent
    @State private var hovered = false

    private var days: Int { event.daysRemaining() }

    private var daysText: String {
        if days < 0 { return "vor \(-days) \(-days == 1 ? "Tag" : "Tagen")" }
        if days == 0 { return "Heute" }
        if days == 1 { return "Morgen" }
        return "\(days) Tage"
    }

    private var daysColor: Color {
        if days < 0  { return .secondary }
        if days == 0 { return .green }
        if days <= 3 { return .red }
        if days <= 7 { return .orange }
        return .primary
    }

    var body: some View {
        HStack(spacing: 12) {
            // Tages-Zahl groß links
            VStack(spacing: 0) {
                Text(days < 0 ? "\(-days)" : "\(days)")
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundStyle(daysColor)
                Text(days < 0 ? "vorbei" : (days == 0 ? "!" : "Tage"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(daysColor.opacity(0.8))
            }
            .frame(width: 48, alignment: .center)

            // Name + Datum
            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(.system(size: 13, weight: days < 0 ? .regular : .medium))
                    .foregroundStyle(days < 0 ? .secondary : .primary)
                    .lineLimit(1)
                Text(event.displayDate)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(hovered ? Color.secondary.opacity(0.07) : Color.clear)
        .onHover { hovered = $0 }
    }
}

// MARK: - Editor

struct CountdownEditorView: View {
    @State private var name: String
    @State private var date: Date
    let isNew: Bool
    let onSave: (CountdownEvent) -> Void
    let onCancel: () -> Void

    private var originalID: UUID

    init(event: CountdownEvent, isNew: Bool,
         onSave: @escaping (CountdownEvent) -> Void,
         onCancel: @escaping () -> Void) {
        _name = State(initialValue: event.name == "Neues Datum" && isNew ? "" : event.name)
        _date = State(initialValue: event.date)
        originalID = event.id
        self.isNew = isNew
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var daysPreview: String {
        let d = CountdownEvent(id: originalID, name: name, date: date).daysRemaining()
        if d < 0  { return "vor \(-d) Tagen"  }
        if d == 0 { return "Heute"             }
        if d == 1 { return "Morgen"            }
        return "in \(d) Tagen"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            VStack(alignment: .leading, spacing: 4) {
                Text("NAME").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                TextField("z.B. Urlaub, Geburtstag, Abgabe…", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("DATUM").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                Text(daysPreview)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)

            Divider()

            HStack {
                Button("Abbrechen", action: onCancel)
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button(isNew ? "Speichern" : "Aktualisieren") {
                    var ev = CountdownEvent()
                    ev.id   = originalID
                    ev.name = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Datum" : name
                    ev.date = date
                    onSave(ev)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }
}
