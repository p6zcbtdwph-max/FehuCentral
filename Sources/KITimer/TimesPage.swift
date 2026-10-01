import SwiftUI

enum TimesTab: String, CaseIterable {
    case countdowns = "Countdown"
    case intervals  = "Intervalle"
}

struct TimesPage: View {
    @Binding var tab: TimesTab
    @EnvironmentObject var tm: TimeManager

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(TimesTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            switch tab {
            case .countdowns: CountdownsPage().environmentObject(tm)
            case .intervals:  IntervalsPage().environmentObject(tm)
            }
        }
    }
}
