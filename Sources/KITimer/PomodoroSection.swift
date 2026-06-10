import SwiftUI

struct PomodoroSection: View {
    @EnvironmentObject var tm: TimeManager

    var body: some View {
        VStack(spacing: 6) {
            if tm.pomodoroPhase == .idle {
                idleRow
            } else {
                activeView
            }
        }
    }

    // MARK: - Idle (kompakt)
    private var idleRow: some View {
        HStack {
            Label("Pomodoro", systemImage: "timer")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Button("▶ Starten") { tm.startPomodoro() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
        }
    }

    // MARK: - Aktiv (expandiert)
    private var activeView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(tm.pomodoroPhase == .work ? "Fokusphase" : "Pause ☕")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(tm.pomodoroDisplayText)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(tm.pomodoroPhase == .work ? .red : .green)
                }
                Spacer()
                HStack(spacing: 10) {
                    Button(action: { tm.togglePomodoroRunning() }) {
                        Image(systemName: tm.pomodoroRunning ? "pause.fill" : "play.fill")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)

                    Button(action: { tm.stopPomodoro() }) {
                        Image(systemName: "stop.fill")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(tm.pomodoroPhase == .work ? Color.red.gradient : Color.green.gradient)
                        .frame(width: max(0, geo.size.width * tm.pomodoroProgress), height: 6)
                        .animation(.linear(duration: 1), value: tm.pomodoroProgress)
                }
            }
            .frame(height: 6)
        }
    }
}
