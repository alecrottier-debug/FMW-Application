import SwiftUI

// Design-system extensions that back the screens (gradients, one-off shades, and
// small reusable components). Views reference these — no raw hex in view code,
// per CLAUDE.md. Shades are sampled directly from Design/prototype.html.
extension FMW {
    // Extra surface/line/text tokens present in the prototype's :root.
    static let lineMint = Color(hex: 0xCFE3D3)
    static let muted    = Color(hex: 0x6E7B70)

    // Home hero: warm sunrise wash → mint (prototype .hero background).
    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0xFFF4E0), Color(hex: 0xFCE9CB), Color(hex: 0xE9F3E7)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    // Radial "sunwash" overlay in the hero's top-right.
    static let sunwash = RadialGradient(
        colors: [Color(hex: 0xF8B45E).opacity(0.55), Color(hex: 0xF8B45E).opacity(0)],
        center: UnitPoint(x: 0.82, y: 0.06), startRadius: 0, endRadius: 220
    )

    // Module tiles.
    static let eventsTile = LinearGradient(
        colors: [Color(hex: 0xEAF4EC), Color(hex: 0xDCEEDF)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let rentTile = LinearGradient(
        colors: [Color(hex: 0xFDEBD3), Color(hex: 0xFBE0BE)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let rentInk = Color(hex: 0x7A4A12) // text on the sun-toned tiles

    // Pills.
    static let pillSunBg = Color(hex: 0xFCEBD6)
    static let pillSunFg = Color(hex: 0x9A5A15)
    static let pillFreeBg = Color(hex: 0xE7F3E9)
    static let pillFreeFg = Color(hex: 0x2B7A4E)

    static let sunInk = Color(hex: 0x3D2410) // legible text/badges on sun-toned surfaces
}

/// Small rounded status/label pill (prototype `.pill`).
struct FMWPill: View {
    let text: String
    var bg: Color
    var fg: Color
    var body: some View {
        Text(text)
            .font(FMW.ui(11.5, .bold))
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(bg, in: Capsule())
    }
}

/// The scalloped pine treeline that sits at the bottom of the Home hero.
struct Treeline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let step = w / 10
        p.move(to: CGPoint(x: 0, y: h))
        var x: CGFloat = 0
        var up = true
        while x < w {
            let cx = x + step / 2
            let cy = up ? h * 0.28 : h * 0.42
            p.addQuadCurve(to: CGPoint(x: x + step, y: h), control: CGPoint(x: cx, y: cy))
            x += step
            up.toggle()
        }
        p.addLine(to: CGPoint(x: w, y: h))
        p.closeSubpath()
        return p
    }
}
