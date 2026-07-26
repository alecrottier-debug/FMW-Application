import SwiftUI
import UIKit
import VisionKit

/// Scan — receipt capture → review expense (spec money flow, prototype
/// data-screen="scan"). The styled dark viewfinder is the launch state; its
/// shutter opens VisionKit's document camera, we read the merchant / date / total
/// on device (Vision), and flip to a "Review expense" form pre-filled with what we
/// found — every field editable, because OCR is a head start, not the last word.
/// Saving uploads the receipt image to the private blob container and writes an
/// Expense (coordinator-gated server-side) so "owed back to volunteers" reconciles.
///
/// On a device without the document camera (Simulator / QA screenshots) it falls
/// back to the prototype's sample review so the flow stays demoable.
/// Built to match Design/prototype.html.
struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AuthService.self) private var auth

    private enum Phase { case camera, review }
    @State private var phase: Phase = .camera

    // Capture + OCR
    @State private var presentingScanner = false
    @State private var capturedImage: UIImage?
    @State private var isReading = false
    @State private var fieldsFound = 0

    // Editable parsed fields
    @State private var merchant = ""
    @State private var dateText = ""
    @State private var totalText = ""

    // Chip selections + live picker data
    @State private var category = "Food & Beverage"
    @State private var paidBy = ""
    @State private var event = ""
    @State private var events: [EventSummary] = []
    @State private var neighbors: [DirectoryEntry] = []

    // Save
    @State private var saving = false
    @State private var errorText: String?

    private let categoryOptions = ["Food & Beverage", "Supplies", "Decor", "Rentals"]
    private let demoPayers = ["Sarah M.", "Dana R.", "Mike K.", "Me"]
    private let demoEvents = ["End-of-Summer Luau", "Summer Sunset Social"]

    private var payerOptions: [String] { neighbors.isEmpty ? demoPayers : neighbors.map(\.name) }
    private var eventOptions: [String] { events.isEmpty ? demoEvents : events.map(\.title) }

    var body: some View {
        ScrollView {
            switch phase {
            case .camera: cameraPhase
            case .review: reviewPhase
            }
        }
        .scrollIndicators(.hidden)
        .background(FMW.cream.ignoresSafeArea())
        .task { await loadPickers() }
        .fullScreenCover(isPresented: $presentingScanner) {
            DocumentScanner { image in
                presentingScanner = false
                if let image { handleCapture(image) }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: Camera phase (styled launch state → real scanner)

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
                Shutter { startScan() }
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
            VStack(alignment: .leading, spacing: 0) {
                ScanBackButton(title: "‹ Rescan", dark: false) { rescan() }
                Text("Review expense")
                    .font(FMW.display(24, .bold))
                    .foregroundStyle(FMW.ink)
                    .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Flash(isReading: isReading, fieldsFound: fieldsFound)
                .padding(.top, 8)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 12) {
                EditableParsedField(label: "Merchant", placeholder: "Merchant name",
                                    text: $merchant)
                EditableParsedField(label: "Date", placeholder: "MMM d, yyyy",
                                    text: $dateText)
                EditableParsedField(label: "Total", placeholder: "$0.00",
                                    text: $totalText, keyboard: .decimalPad, tabular: true)

                ChipField(label: "Category", options: categoryOptions, selection: $category)
                ChipField(label: "Paid by", options: payerOptions, selection: $paidBy)
                ChipField(label: "Apply to event", options: eventOptions, selection: $event)
            }
            .padding(.horizontal, 18)

            if let errorText {
                Text(errorText)
                    .font(FMW.ui(12.5, .semibold))
                    .foregroundStyle(FMW.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
            }

            Button { Task { await save() } } label: {
                HStack(spacing: 8) {
                    if saving { ProgressView().tint(.white) }
                    Text(saving ? "Saving…" : "Save expense · track to \(trackName)")
                        .font(FMW.ui(15, .bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(FMW.pine, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: FMW.pine.opacity(0.5), radius: 11, x: 0, y: 12)
            }
            .buttonStyle(.plain)
            .disabled(saving)
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 22)
        }
    }

    private var trackName: String {
        paidBy == "Me" ? "you" : String(paidBy.split(separator: " ").first ?? "the payer")
    }

    // MARK: Actions

    private func startScan() {
        errorText = nil
        if DocumentScanner.isAvailable {
            presentingScanner = true
        } else {
            fillDemo()             // Simulator / no camera → prototype sample
            phase = .review
        }
    }

    private func handleCapture(_ image: UIImage) {
        capturedImage = image
        isReading = true
        fieldsFound = 0
        merchant = ""; dateText = ""; totalText = ""
        phase = .review
        Task {
            let parsed = await ReceiptOCR.scan(image)
            apply(parsed)
            isReading = false
        }
    }

    private func apply(_ parsed: ParsedReceipt) {
        if let m = parsed.merchant { merchant = m }
        if let d = parsed.date { dateText = Self.displayDate.string(from: d) }
        if let t = parsed.total { totalText = "$" + (Self.amountFmt.string(from: t as NSDecimalNumber) ?? "\(t)") }
        fieldsFound = parsed.fieldsFound
    }

    private func rescan() {
        errorText = nil
        capturedImage = nil
        phase = .camera
    }

    private func fillDemo() {
        merchant = "COSTCO WHOLESALE #1071"
        dateText = "Aug 28, 2026"
        totalText = "$142.60"
        fieldsFound = 3
    }

    private func save() async {
        errorText = nil
        guard let amount = Self.parseAmount(totalText), amount > 0 else {
            errorText = "Enter the receipt total (e.g. $142.60)."
            return
        }
        // Demo mode (no API): keep the prototype behavior — just close.
        guard AppConfig.isAPIConfigured else { dismiss(); return }

        saving = true
        let request = CreateExpenseRequest(
            eventId: eventId(for: event),
            paidByUserId: payerId(for: paidBy) ?? auth.currentUser?.id,
            merchant: merchant.trimmed.isEmpty ? nil : merchant.trimmed,
            date: Self.isoDate(from: dateText),
            amount: amount,
            tax: nil,
            category: category,
            receiptBase64: capturedImage?.jpegData(compressionQuality: 0.7)?.base64EncodedString(),
            receiptContentType: "image/jpeg"
        )
        do {
            try await ExpenseService().create(request)
            dismiss()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            saving = false
        }
    }

    private func loadPickers() async {
        guard AppConfig.isAPIConfigured else { return }
        let service = ExpenseService()
        if let live = try? await service.events(), !live.isEmpty {
            events = live
            if event.isEmpty { event = live[0].title }
        }
        if let people = try? await service.neighbors(), !people.isEmpty {
            neighbors = people
            if paidBy.isEmpty {
                paidBy = auth.currentUser.flatMap { me in people.first { $0.id == me.id }?.name }
                    ?? people[0].name
            }
        }
        if event.isEmpty { event = demoEvents[0] }
        if paidBy.isEmpty { paidBy = auth.currentUser?.name ?? demoPayers[0] }
    }

    private func eventId(for title: String) -> String? { events.first { $0.title == title }?.id }
    private func payerId(for name: String) -> String? { neighbors.first { $0.name == name }?.id }

    // MARK: Formatting helpers

    private static let displayDate: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "MMM d, yyyy"; return f
    }()
    private static let amountFmt: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .decimal
        f.minimumFractionDigits = 2; f.maximumFractionDigits = 2; return f
    }()

    private static func parseAmount(_ s: String) -> Double? {
        Double(s.filter { $0.isNumber || $0 == "." })
    }

    /// Turn the (editable) display date back into "YYYY-MM-DD", or nil if unparseable.
    private static func isoDate(from text: String) -> String? {
        let candidates = ["MMM d, yyyy", "MMMM d, yyyy", "MM/dd/yyyy", "M/d/yyyy",
                          "MM/dd/yy", "M/d/yy", "yyyy-MM-dd", "MM-dd-yyyy"]
        let parser = DateFormatter(); parser.locale = Locale(identifier: "en_US_POSIX")
        for format in candidates {
            parser.dateFormat = format
            if let date = parser.date(from: text.trimmed) {
                let out = DateFormatter(); out.locale = Locale(identifier: "en_US_POSIX")
                out.dateFormat = "yyyy-MM-dd"
                return out.string(from: date)
            }
        }
        return nil
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension DocumentScanner {
    /// True when the on-device document camera is available (false on Simulator).
    static var isAvailable: Bool { VNDocumentCameraViewController.isSupported }
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
    let isReading: Bool
    let fieldsFound: Int

    var body: some View {
        HStack(spacing: 8) {
            if isReading {
                ProgressView().tint(FMW.pine)
                Text("Reading receipt on device…")
                    .font(FMW.ui(13, .bold))
                    .foregroundStyle(FMW.pine)
            } else {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(FMW.pine)
                Text("Read on device · \(fieldsFound) field\(fieldsFound == 1 ? "" : "s") found")
                    .font(FMW.ui(13, .bold))
                    .foregroundStyle(FMW.pine)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// A parsed, read-on-device field (.field.parsed-hit) — now an editable text field
/// so the coordinator can correct anything OCR got wrong.
private struct EditableParsedField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var tabular: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased())
                .font(FMW.ui(11, .bold))
                .tracking(0.5)
                .foregroundStyle(FMW.muted)
            HStack {
                TextField(placeholder, text: $text)
                    .font(tabular ? FMW.ui(15, .semibold).monospacedDigit() : FMW.ui(15, .semibold))
                    .foregroundStyle(FMW.ink)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled()
                Image(systemName: "pencil")
                    .font(.system(size: 12, weight: .bold))
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
        .accessibilityLabel("\(label): \(text.isEmpty ? placeholder : text)")
        .accessibilityHint("Editable")
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
        .environment(AuthService())
}
