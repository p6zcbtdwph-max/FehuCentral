import SwiftUI

@main
struct KITimerApp: App {
    @StateObject private var tm   = TimeManager()
    @StateObject private var clip = ClipboardManager()
    @StateObject private var cal  = CalendarManager()
    @StateObject private var gam  = GamificationManager()

    var body: some Scene {
        MenuBarExtra {
            MainMenuView()
                .environmentObject(tm)
                .environmentObject(clip)
                .environmentObject(cal)
                .environmentObject(gam)
        } label: {
            HStack(spacing: 3) {
                Text("ᚠ")
                    .font(.system(size: 13, weight: .semibold))
                Text(tm.menuBarText)
                    .monospacedDigit()
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
