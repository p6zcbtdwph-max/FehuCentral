import SwiftUI

struct FehuRune: View {
    var height: CGFloat = 15

    private var w: CGFloat { height * 0.60 }

    var body: some View {
        ZStack {
            runePath
                .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .square))
        }
        .frame(width: w, height: height)
    }

    private var runePath: Path {
        Path { p in
            let lx = w * 0.10   // linke Stablinie
            let rx = w * 0.40   // rechte Stablinie

            // Linke Stablinie (etwas breiter gezeichnet mit zwei eng beieinander liegenden Linien)
            p.move(to:    CGPoint(x: lx,        y: 0))
            p.addLine(to: CGPoint(x: lx,        y: height))
            p.move(to:    CGPoint(x: lx + 1.2,  y: 0))
            p.addLine(to: CGPoint(x: lx + 1.2,  y: height))

            // Rechte Stablinie
            p.move(to:    CGPoint(x: rx, y: 0))
            p.addLine(to: CGPoint(x: rx, y: height))

            // Oberer Ast: leicht aufwärts nach rechts
            p.move(to:    CGPoint(x: rx,  y: height * 0.13))
            p.addLine(to: CGPoint(x: w,   y: height * 0.07))

            // Unterer Ast: flacherer Winkel
            p.move(to:    CGPoint(x: rx - 1, y: height * 0.36))
            p.addLine(to: CGPoint(x: w,      y: height * 0.29))
        }
    }
}
