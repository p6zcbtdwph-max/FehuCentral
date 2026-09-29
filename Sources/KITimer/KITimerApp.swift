import SwiftUI
import AppKit

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
                Text(tm.menuBarText)
                    .monospacedDigit()
                    .font(.system(size: 12, weight: .medium))
                Text("ᚠ")
                    .font(Font(NSFont(name: "Arial Unicode MS", size: 14) ?? NSFont.systemFont(ofSize: 14, weight: .semibold)))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
