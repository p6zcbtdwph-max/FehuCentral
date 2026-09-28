import SwiftUI
import EventKit

struct CalendarPage: View {
    @EnvironmentObject var cal: CalendarManager

    var body: some View {
        VStack(spacing: 0) {
            switch cal.authStatus {
            case .fullAccess:
                eventList
            case .notDetermined:
                permissionView
            default:
                deniedView
            }
        }
    }

    // MARK: - Termine

    private var eventList: some View {
        VStack(spacing: 0) {
            if cal.todayEvents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 28)).foregroundStyle(.secondary)
                    Text("Keine Termine heute")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(cal.todayEvents) { event in
                            CalendarEventRow(event: event)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 300)
            }

            Divider()

            Button(action: { cal.fetchToday() }) {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Berechtigung

    private var permissionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32)).foregroundStyle(.orange)
            Text("Kalender-Zugriff")
                .font(.system(size: 14, weight: .semibold))
            Text("Fehu Central kann deine heutigen Termine anzeigen.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Zugriff erlauben") { cal.requestAccess() }
                .buttonStyle(.borderedProminent).controlSize(.regular)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private var deniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 32)).foregroundStyle(.red)
            Text("Kein Kalender-Zugriff")
                .font(.system(size: 14, weight: .semibold))
            Text("Zugriff in Systemeinstellungen → Datenschutz → Kalender erlauben.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Systemeinstellungen öffnen") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
            }
            .buttonStyle(.borderedProminent).controlSize(.small)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Einzelner Termin

struct CalendarEventRow: View {
    let event: CalendarEvent
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Kalender-Farbe als Balken
            RoundedRectangle(cornerRadius: 2)
                .fill(event.calendarColor)
                .frame(width: 3, height: event.isActive ? 44 : 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if event.isActive {
                        Circle().fill(.green).frame(width: 6, height: 6)
                    }
                    Text(event.title)
                        .font(.system(size: 13, weight: event.isActive ? .semibold : .regular))
                        .lineLimit(1)
                }
                Text(event.timeRange)
                    .font(.system(size: 11)).foregroundStyle(.secondary)

                // Fortschrittsbalken bei laufendem Termin
                if event.isActive {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(event.calendarColor)
                                .frame(width: geo.size.width * event.progress, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(hovered ? Color.secondary.opacity(0.07) : Color.clear)
        .onHover { hovered = $0 }
    }
}
