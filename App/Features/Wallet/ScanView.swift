import SwiftUI

/// Scan — receipt capture → review expense (spec money flow, prototype
/// data-screen="scan"). A dark on-device camera phase (striped viewfinder,
/// floating receipt ghost, reticle + sweep, shutter) flips to a "Review expense"
/// form: the parsed merchant / date / total, plus chip pickers to assign a
/// category, the person who paid, and the event to charge it to. Every scan
/// writes a line item back to an event so "who paid for what" reconciles.
/// Built to match Design/prototype.html.
struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase { case camera, review }
    @State private var phase: Phase = .camera

    @State private var category = "Food & Beverage"
    @State private var paidBy   = "Sarah M."
    @State private var event    = "End-of-Summer Luau"

    var body: some View {
        ScrollView {
            switch phase {
            case .camera: cameraPhase
            case .review: reviewPhase
            }
        }
        .scrollIndicators(.hidden)
        .background(FMW.cream.ignoresSafeArea())
    }

    // MARK: Camera phase

    private var cameraPhase: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ScanBackButton(title: "‹ Cancel", dark: true) { dismiss() }
                Text("Scan receipt")
                    .font(FMW.ui(14, .bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)

            CameraArea(reduceMotion: reduceMotion)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            VStack(spacing: 12) {
                Text("Line up the receipt — we’ll read the merchant, date & total on device.")
                    .font(FMW.ui(13))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Shutter { phase = .review }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
        .background(ScanColor.scanBg)
        .containerRelativeFrame(.vertical)
    }

    // MARK: Review phase

    private var reviewPhase: some View {
        VStack(spacing: 0) {
            // detail hero (on cream)
            VStack(alignment: .leading, spacing: 0) {
                ScanBackButton(title: "‹ Rescan", dark: false) { phase = .camera }
                Text("Review expense")
                    .font(FMW.display(24, .bold))
                    .foregroundStyle(FMW.ink)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Flash()
                .padding(.top, 8)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 12) {
                ParsedField(label: "Merchant", value: "COSTCO WHOLESALE #1071")
                ParsedField(label: "Date", value: "Aug 28, 2026")
                ParsedField(label: "Total", value: "$142.60", tabular: true)

                ChipField(label: "Category",
                          options: ["Food & Beverage", "Supplies", "Decor", "Rentals"],
                          selection: $category)
                ChipField(label: "Paid by",
                          options: ["Sarah M.", "Dana R.", "Mike K.", "Me"],
                          selection: $paidBy)
                ChipField(label: "Apply to event",
                          options: ["End-of-Summer Luau", "Summer Sunset Social"],
                          selection: $event)
            }
            .padding(.horizontal, 18)

            Button { dismiss() } label: {
                Text("Save expense · track to \(trackName)")
                    .font(FMW.ui(15, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FMW.pine, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: FMW.pine.opacity(0.5), radius: 11, x: 0, y: 12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 22)
        }
    }

    private var trackName: String {
        paidBy == "Me" ? "you" : String(paidBy.split(separator: " ").first ?? "")
    }
}

// MARK: - One-off shades sampled from the prototype (no raw hex in view bodies)

private enum ScanColor {
    static let scanBg        = Color(hex: 0x0F231D)   // .scanview dark base
    static let stripeA       = Color(hex: 0x20463A)   // camera weave, light band
    static let stripeB       = Color(hex: 0x1C3E33)   // camera weave, dark band
    static let receiptLine   = Color(hex: 0xE5E0D4)   // ghost receipt text lines
    static let receiptBig    = Color(hex: 0xCFC8B8)   // ghost receipt total line
    static let parsedHitBg   = Color(hex: 0xF5FBF6)   // .parsed-hit field fill
}

// MARK: - Back button (.backbtn — dark on camera, light on the cream hero)

private struct ScanBackButton: View {
    let title: String
    var dark: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FMW.ui(13, .semibold))
                .foregroundStyle(dark ? Color.white : FMW.pineDeep)
                .padding(.leading, 10)
                .padding(.trailing, 13)
                .padding(.vertical, 8)
                .background(dark ? Color.white.opacity(0.12) : Color.white.opacity(0.7), in: Capsule())
                .overlay(Capsule().stroke(dark ? Color.white.opacity(0.2) : FMW.lineMint, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Camera viewfinder

private struct CameraArea: View {
    let reduceMotion: Bool
    @State private var sweepDown = false

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 34
            let top = inset + 10
            let bottom = max(top, geo.size.height - inset - 10)

            ZStack {
                DiagonalStripes()

                ReceiptGhost()

                // Darken everything outside the reticle window.
                ReticleSurround(inset: inset, radius: 16)
                    .fill(ScanColor.scanBg.opacity(0.35), style: FillStyle(eoFill: true))

                // Reticle window border.
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .inset(by: inset)
                    .stroke(FMW.sun2.opacity(0.9), lineWidth: 2)

                // Corner brackets.
                cornerBrackets(size: geo.size, inset: inset)

                // Scanning sweep line.
                if reduceMotion {
                    SweepBar()
                        .frame(width: geo.size.width - inset * 2, height: 3)
                        .position(x: geo.size.width / 2, y: (top + bottom) / 2)
                } else {
                    SweepBar()
                        .frame(width: geo.size.width - inset * 2, height: 3)
                        .position(x: geo.size.width / 2, y: sweepDown ? bottom : top)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                                sweepDown = true
                            }
                        }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .frame(minHeight: 300)
        .accessibilityElement()
        .accessibilityLabel("Camera viewfinder. Line up the receipt.")
    }

    private func cornerBrackets(size: CGSize, inset: CGFloat) -> some View {
        ZStack {
            CornerBracket().stroke(FMW.sun2, style: cornerStroke)
                .frame(width: 22, height: 22)
                .position(x: inset + 11, y: inset + 11)
            CornerBracket().stroke(FMW.sun2, style: cornerStroke)
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(90))
                .position(x: size.width - inset - 11, y: inset + 11)
            CornerBracket().stroke(FMW.sun2, style: cornerStroke)
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(180))
                .position(x: size.width - inset - 11, y: size.height - inset - 11)
            CornerBracket().stroke(FMW.sun2, style: cornerStroke)
                .frame(width: 22, height: 22)
                .rotationEffect(.degrees(270))
                .position(x: inset + 11, y: size.height - inset - 11)
        }
    }

    private var cornerStroke: StrokeStyle {
        StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
    }
}

/// The 115° two-tone weave behind the viewfinder (repeating-linear-gradient).
private struct DiagonalStripes: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(ScanColor.stripeB))
            let diag = (size.width * size.width + size.height * size.height).squareRoot()
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.rotate(by: .degrees(115))
            var x = -diag
            while x < diag {
                ctx.fill(Path(CGRect(x: x, y: -diag, width: 22, height: diag * 2)),
                         with: .color(ScanColor.stripeA))
                x += 44
            }
        }
    }
}

/// Full bounds with the reticle window punched out (even-odd fill).
private struct ReticleSurround: Shape {
    var inset: CGFloat
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)
        p.addRoundedRect(in: rect.insetBy(dx: inset, dy: inset),
                         cornerSize: CGSize(width: radius, height: radius))
        return p
    }
}

/// One reticle corner (top-left orientation); rotate for the other three.
private struct CornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 8
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

private struct SweepBar: View {
    var body: some View {
        LinearGradient(colors: [.clear, FMW.sun2, .clear],
                       startPoint: .leading, endPoint: .trailing)
            .shadow(color: FMW.sun2.opacity(0.6), radius: 8)
    }
}

/// The floating cream receipt inside the viewfinder.
private struct ReceiptGhost: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            line(76)
            line(107)
            line(126)
            line(107)
            line(76)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(ScanColor.receiptBig)
                .frame(width: 88, height: 12)
                .padding(.top, 5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(width: 150, alignment: .leading)
        .background(FMW.cream)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .rotationEffect(.degrees(-3))
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 14)
        .accessibilityHidden(true)
    }

    private func line(_ width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(ScanColor.receiptLine)
            .frame(width: width, height: 7)
    }
}

private struct Shutter: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Color.white).frame(width: 54, height: 54)
                Circle().stroke(Color.white.opacity(0.4), lineWidth: 5).frame(width: 62, height: 62)
            }
            .frame(width: 64, height: 64)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Capture receipt")
    }
}

// MARK: - Parsed review fields

private struct Flash: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(FMW.pine)
            Text("Read on device · 3 fields found")
                .font(FMW.ui(13, .bold))
                .foregroundStyle(FMW.pine)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A parsed, read-on-device field (.field.parsed-hit) with an Edit affordance.
private struct ParsedField: View {
    let label: String
    let value: String
    var tabular: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(FMW.ui(11, .bold))
                .tracking(0.5)
                .foregroundStyle(FMW.muted)
            HStack {
                valueText
                Spacer(minLength: 8)
                Text("Edit")
                    .font(FMW.ui(11, .bold))
                    .foregroundStyle(FMW.pine)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(ScanColor.parsedHitBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(FMW.lineMint, lineWidth: 1.5)
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
        .accessibilityHint("Double tap to edit")
    }

    private var valueText: some View {
        let base = tabular
            ? Text(value).font(FMW.ui(15, .semibold)).monospacedDigit()
            : Text(value).font(FMW.ui(15, .semibold))
        return base.foregroundStyle(FMW.ink)
    }
}

/// A labelled row of single-select chips (.field with a .chipset of .selchip).
private struct ChipField: View {
    let label: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(FMW.ui(11, .bold))
                .tracking(0.5)
                .foregroundStyle(FMW.muted)
            ChipFlow(spacing: 8, lineSpacing: 8) {
                ForEach(options, id: \.self) { opt in
                    SelChip(text: opt, on: opt == selection) { selection = opt }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SelChip: View {
    let text: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(FMW.ui(13, .semibold))
                .foregroundStyle(on ? Color.white : FMW.pineDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(on ? FMW.pine : FMW.paper,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(on ? FMW.pine : FMW.lineMint, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}

/// Lightweight flow layout so chips wrap to new lines under Dynamic Type.
private struct ChipFlow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                y += rowHeight + lineSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(maxWidth, widest), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                y += rowHeight + lineSpacing
                x = bounds.minX
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    ScanView()
}
