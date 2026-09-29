import SwiftUI

struct FehuRune: View {
    var height: CGFloat = 15

    private var width: CGFloat { height * 0.60 }

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height

            func seg(_ x1: CGFloat, _ y1: CGFloat,
                     _ x2: CGFloat, _ y2: CGFloat,
                     lw: CGFloat) {
                var p = Path()
                p.move(to: CGPoint(x: x1 * w, y: y1 * h))
                p.addLine(to: CGPoint(x: x2 * w, y: y2 * h))
                ctx.stroke(p, with: .foreground,
                           style: StrokeStyle(lineWidth: lw, lineCap: .square))
            }

            let thick: CGFloat = h * 0.083   // linker Stab (breiter)
            let thin:  CGFloat = h * 0.065   // rechter Stab + Äste (schmaler)

            // Doppelter Stab – linke Linie
            seg(0.13, 0.01, 0.13, 0.99, lw: thick)
            // Doppelter Stab – rechte Linie (mit Hohlraum)
            seg(0.40, 0.01, 0.40, 0.99, lw: thin)

            // Oberer Ast: startet von rechter Stablinie, leicht aufwärts nach rechts
            seg(0.40, 0.13, 1.00, 0.08, lw: thin)

            // Unterer Ast: startet leicht links der rechten Stablinie, flacher Winkel
            seg(0.33, 0.36, 1.00, 0.29, lw: thin)
        }
        .frame(width: width, height: height)
    }
}
