import SwiftUI

struct ProgressRow: View {
    let label: String
    let systemImage: String
    let progress: Double
    let remainingText: String

    private var barColor: Color {
        switch progress {
        case ..<0.5:  return .green
        case ..<0.75: return Color(hue: 0.17, saturation: 0.9, brightness: 0.9) // yellow-orange
        case ..<0.9:  return .orange
        default:      return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Label(label, systemImage: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor.gradient)
                        .frame(width: max(4, geo.size.width * progress), height: 8)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: 8)

            Text(remainingText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
