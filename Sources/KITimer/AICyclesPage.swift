import SwiftUI

struct AICyclesPage: View {
    @EnvironmentObject var ai: AICycleManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KI-Zyklen verfolgen").font(.system(size: 13))
                        Text("Wochenlimit und Sitzungsfenster im Blick behalten.")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { ai.enabled }, set: { ai.enabled = $0 })).labelsHidden()
                }
                .padding(.horizontal, 16).padding(.vertical, 10)

                if ai.enabled {
                    Divider()
                    weekly
                    Divider()
                    session
                }
            }
        }
        .frame(maxHeight: 420)
    }

    // MARK: - Wochenlimit

    private var weekly: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Wochenlimit")

            HStack {
                Text("Wochen-Reset").font(.system(size: 13))
                Spacer()
                DatePicker("", selection: Binding(get: { ai.weeklyAnchor }, set: { ai.weeklyAnchor = $0 }),
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact).labelsHidden()
            }
            Text("Wiederholt sich alle 7 Tage. Nächster Reset: \(ai.weekEnd.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute()))")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 4) {
                HStack {
                    Text("Verbraucht").font(.system(size: 13))
                    Spacer()
                    Text(AICycleManager.pct(ai.usedNow))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
                Slider(value: Binding(get: { ai.usedNow }, set: { ai.setUsed($0.rounded()) }), in: 0...100)
            }

            statusCard
            dayStrip
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ai.statusText)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ai.statusColor)

            LimitBar(used: ai.usedNow, target: ai.targetPercent, color: ai.statusColor, height: 8)

            HStack(spacing: 6) {
                stat("Soll jetzt", AICycleManager.pct(ai.targetPercent))
                stat("Ist", AICycleManager.pct(ai.usedNow))
                stat("Frei", AICycleManager.pct(ai.freePercent))
                stat("Pro Tag", AICycleManager.pct(ai.perDayPercent))
            }

            let left = ai.todayAllowanceLeft
            Text(left >= 0
                 ? "Tag \(ai.dayIndex + 1) von 7: bis \(ai.dayEnd.formatted(.dateTime.weekday(.abbreviated).hour().minute())) noch \(AICycleManager.pct(left)) erlaubt."
                 : "Tag \(ai.dayIndex + 1) von 7: Tagesbudget um \(AICycleManager.pct(-left)) überschritten.")
                .font(.system(size: 10)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    private var dayStrip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Erlaubter Verbrauch bis Ende jedes Tages")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    let current = i == ai.dayIndex
                    VStack(spacing: 1) {
                        Text(ai.dayStart(i).formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                        Text("\(Int((Double(i + 1) * ai.perDayPercent).rounded()))%")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(current ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .opacity(i < ai.dayIndex ? 0.55 : 1)
                }
            }
        }
    }

    // MARK: - Sitzung

    private var session: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Sitzung")

            if ai.sessionActive, let end = ai.sessionEnd {
                HStack {
                    Text("Reset in \(ai.sessionRemainingText)")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text(end.formatted(.dateTime.hour().minute()) + " Uhr")
                        .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                }
                XPBar(progress: ai.sessionProgress, color: .purple, height: 8)
            } else {
                Text(ai.sessionEnd == nil ? "Keine Sitzung gestartet" : "Letzte Sitzung ist abgelaufen")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button(ai.sessionActive ? "Neu starten (\(ai.sessionHours) h)" : "Jetzt starten (\(ai.sessionHours) h)") {
                    ai.startSession()
                }
                .buttonStyle(.borderedProminent).controlSize(.small)
                if ai.sessionActive {
                    Button("Beenden") { ai.endSession() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }

            HStack {
                Text("Reset-Uhrzeit eintragen").font(.system(size: 13))
                Spacer()
                DatePicker("", selection: Binding(get: { ai.sessionEnd ?? Date() }, set: { ai.setSessionReset(toClockOf: $0) }),
                           displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }

            HStack {
                Text("Sitzungslänge").font(.system(size: 13))
                Spacer()
                Text("\(ai.sessionHours) h")
                    .font(.system(size: 13, design: .monospaced)).foregroundStyle(.secondary)
                Stepper("", value: Binding(get: { ai.sessionHours }, set: { ai.sessionHours = $0 }), in: 1...12)
                    .labelsHidden()
            }

            HStack {
                Text("Statt Intervall auf der Hauptseite").font(.system(size: 13))
                Spacer()
                Toggle("", isOn: Binding(get: { ai.showSessionOnMain }, set: { ai.showSessionOnMain = $0 })).labelsHidden()
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    // MARK: - Hilfen

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 11, weight: .semibold, design: .monospaced))
            Text(label).font(.system(size: 8)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Verbrauchsbalken mit Markierung für den Soll-Stand.
struct LimitBar: View {
    let used: Double      // 0...100
    let target: Double    // 0...100
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.secondary.opacity(0.14))
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color.opacity(0.85))
                    .frame(width: geo.size.width * min(1, max(0, used / 100)))
                Rectangle()
                    .fill(Color.primary.opacity(0.75))
                    .frame(width: 2, height: height + 4)
                    .offset(x: geo.size.width * min(1, max(0, target / 100)) - 1)
            }
            .frame(height: height)
            .frame(maxHeight: .infinity)
        }
        .frame(height: height + 4)
    }
}
