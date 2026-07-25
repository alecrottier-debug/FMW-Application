import SwiftUI

/// Event editor — the coordinator's "New event" form (spec: eventCoordinator can
/// create events). Mirrors Design/prototype.html (data-screen="event-editor"):
/// name, date/time, location, audience, description, then the ticketing choice.
/// The heart of the screen is the PAID ITEMS repeater — events have many paid
/// line items (Adult ticket, Kid ticket, Chili entry, T-shirt…), never one price —
/// so neighbors can add/remove any number of buyable items. Closes with RSVP
/// deadline, budget target, coordinators, visibility, and Save draft / Publish.
struct EventEditorView: View {
    @Environment(\.dismiss) private var dismiss

    // Basics
    @State private var name = ""
    @State private var when = Date()
    @State private var location = "Pavilion"
    @State private var audience = "Family"
    @State private var details = ""

    // Save state
    @State private var saving = false
    @State private var errorText: String?

    // Ticketing
    @State private var ticketing: Ticketing = .free
    @State private var items: [PaidItem] = [
        PaidItem(name: "Adult ticket",        price: "$35.00", sub: "Limit 120 · per person"),
        PaidItem(name: "Kid ticket (under 12)", price: "$10.00", sub: "Limit 80 · per person"),
        PaidItem(name: "Chili entry",         price: "$15.00", sub: "Limit 24 · per household"),
        PaidItem(name: "Event T-shirt",       price: "$20.00", sub: "Optional add-on · sizes at pickup")
    ]
    @State private var showAddForm = false
    @State private var newItemName = ""
    @State private var newItemPrice = ""
    @State private var newItemLimit = ""
    @State private var rsvpDeadline = ""

    // Wrap-up
    @State private var budget = ""
    @State private var coordinators: Set<String> = ["You (Alex R.)"]
    @State private var visibility = "All residents"

    private let locations = ["Pavilion", "Pool deck", "Clubhouse", "Other"]
    private let audiences = ["Family", "Adults", "Kids"]
    private let coordinatorOptions = ["You (Alex R.)", "+ Sarah M.", "+ Dana R."]
    private let visibilityOptions = ["All residents", "Invite only"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                EventEditorHero(onBack: { dismiss() })

                basics
                ticketingSection
                if ticketing == .paid { paidSection }
                wrapUp

                if let errorText {
                    Text(errorText)
                        .font(FMW.ui(12.5, .semibold))
                        .foregroundStyle(FMW.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18).padding(.top, 4)
                }

                EventEditorFooter(saving: saving,
                                  onDraft: { save(status: "draft") },
                                  onPublish: { save(status: "published") })
                    .padding(.top, 6)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 26)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(FMW.cream.ignoresSafeArea())
    }

    // MARK: Basics

    @ViewBuilder private var basics: some View {
        EventEditorField(label: "Event name") {
            EventEditorInput(placeholder: "e.g. Fall Chili Cook-off", text: $name)
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 12)

        EventEditorField(label: "Date & time") {
            DatePicker("", selection: $when, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(FMW.pine)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FMW.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(FMW.line, lineWidth: 1.5))
        }
        .padding(.horizontal, 14).padding(.bottom, 12)

        EventEditorField(label: "Location") {
            EventEditorChipset(options: locations, selection: $location)
        }
        .padding(.horizontal, 14).padding(.bottom, 12)

        EventEditorField(label: "Audience") {
            EventEditorChipset(options: audiences, selection: $audience)
        }
        .padding(.horizontal, 14).padding(.bottom, 12)

        EventEditorField(label: "Description") {
            EventEditorInput(placeholder: "What should neighbors know?", text: $details, multiline: true)
        }
        .padding(.horizontal, 14).padding(.bottom, 12)
    }

    // MARK: Ticketing choice

    @ViewBuilder private var ticketingSection: some View {
        EventEditorField(label: "Ticketing") {
            EventEditorFlow {
                EventEditorChip(label: "Free · RSVP", isOn: ticketing == .free) { ticketing = .free }
                EventEditorChip(label: "Paid items", isOn: ticketing == .paid) { ticketing = .paid }
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 14).padding(.bottom, 12)
    }

    // MARK: Paid-items repeater

    @ViewBuilder private var paidSection: some View {
        EventEditorLabel(text: "Paid items · what neighbors can buy")
            .padding(.horizontal, 14).padding(.bottom, 8)

        ForEach(items) { item in
            EventEditorItemCard(item: item) { remove(item) }
                .padding(.horizontal, 14).padding(.bottom, 10)
        }

        Button {
            showAddForm.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                Text("Add another paid item").font(FMW.ui(13.5, .bold))
            }
            .foregroundStyle(FMW.pineDeep)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(FMW.mint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(FMW.lineMint, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14).padding(.top, 2).padding(.bottom, 14)

        if showAddForm {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    EventEditorSmallInput(placeholder: "Item name (e.g. Raffle ticket)", text: $newItemName)
                    EventEditorSmallInput(placeholder: "$5", text: $newItemPrice)
                        .frame(width: 84)
                }
                HStack(spacing: 8) {
                    EventEditorSmallInput(placeholder: "Limit (optional)", text: $newItemLimit)
                    Button(action: addItem) {
                        Text("Add")
                            .font(FMW.ui(13.5, .bold))
                            .foregroundStyle(.white)
                            .frame(width: 84, height: 38)
                            .background(FMW.pine, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.bottom, 14)
        }

        EventEditorField(label: "RSVP deadline") {
            EventEditorInput(placeholder: "Oct 8, 2026", text: $rsvpDeadline)
        }
        .padding(.horizontal, 14).padding(.bottom, 12)
    }

    // MARK: Wrap-up

    @ViewBuilder private var wrapUp: some View {
        EventEditorField(label: "Budget target") {
            EventEditorInput(placeholder: "$1,200", text: $budget)
        }
        .padding(.horizontal, 14).padding(.bottom, 12)

        EventEditorField(label: "Coordinators") {
            EventEditorFlow {
                ForEach(coordinatorOptions, id: \.self) { c in
                    EventEditorChip(label: c, isOn: coordinators.contains(c)) {
                        if coordinators.contains(c) { coordinators.remove(c) }
                        else { coordinators.insert(c) }
                    }
                }
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 14).padding(.bottom, 12)

        EventEditorField(label: "Visibility") {
            EventEditorChipset(options: visibilityOptions, selection: $visibility)
        }
        .padding(.horizontal, 14).padding(.bottom, 12)
    }

    // MARK: Actions

    private func remove(_ item: PaidItem) {
        items.removeAll { $0.id == item.id }
    }

    private func addItem() {
        let trimmed = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let price = newItemPrice.trimmingCharacters(in: .whitespaces)
        let limit = newItemLimit.trimmingCharacters(in: .whitespaces)
        let sub = limit.isEmpty ? "Optional add-on" : "Limit \(limit)"
        items.append(PaidItem(name: trimmed, price: price.isEmpty ? "$0" : price, sub: sub))
        newItemName = ""; newItemPrice = ""; newItemLimit = ""
        showAddForm = false
    }

    /// Create the event (draft or published) via the API, then close.
    private func save(status: String) {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { errorText = "Give the event a name."; return }
        errorText = nil

        // Demo mode (no API configured): nothing to persist — just close.
        guard AppConfig.isAPIConfigured else { dismiss(); return }

        saving = true
        let iso = ISO8601DateFormatter()
        let request = CreateEventRequest(
            title: title,
            startAt: iso.string(from: when),
            endAt: nil,
            location: location,
            audience: audience,
            description: details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : details,
            ticketingType: ticketing == .paid ? "paid" : "free",
            budgetTarget: Self.parseMoney(budget),
            visibility: visibility == "Invite only" ? "invite" : "all",
            status: status,
            items: ticketing == .paid ? items.map { item in
                CreateEventItem(
                    name: item.name,
                    price: Self.parseMoney(item.price) ?? 0,
                    limit: Self.parseLimit(item.sub),
                    isOptional: item.sub.lowercased().contains("optional")
                )
            } : []
        )
        Task {
            do {
                try await EventsService().create(request)
                dismiss()
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                saving = false
            }
        }
    }

    private static func parseMoney(_ s: String) -> Double? {
        Double(s.filter { $0.isNumber || $0 == "." })
    }

    private static func parseLimit(_ s: String) -> Int? {
        let digits = s.drop { !$0.isNumber }.prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int(digits)
    }
}

// MARK: - Model

private struct PaidItem: Identifiable {
    let id = UUID()
    var name: String
    var price: String
    var sub: String
}

private enum Ticketing { case free, paid }

// MARK: - Hero

private struct EventEditorHero: View {
    let onBack: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left").font(.system(size: 13, weight: .semibold))
                    Text("Events").font(FMW.ui(13, .semibold))
                }
                .foregroundStyle(FMW.pineDeep)
                .padding(.leading, 10).padding(.trailing, 13).padding(.vertical, 8)
                .background(Color.white.opacity(0.7), in: Capsule())
                .overlay(Capsule().stroke(FMW.lineMint, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Events")

            Text("EVENT COORDINATOR")
                .font(FMW.ui(11, .heavy))
                .tracking(1.32)
                .foregroundStyle(FMW.sun)
                .padding(.top, 12)

            Text("New event")
                .font(FMW.display(25, .bold))
                .foregroundStyle(FMW.ink)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(EventEditorTokens.hero)
    }
}

// MARK: - Field + label

private struct EventEditorLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(FMW.ui(11, .bold))
            .tracking(0.55)
            .foregroundStyle(FMW.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EventEditorField<Content: View>: View {
    let label: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            EventEditorLabel(text: label)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Inputs

private struct EventEditorInput: View {
    let placeholder: String
    @Binding var text: String
    var multiline = false

    private var prompt: Text {
        Text(placeholder).font(FMW.ui(15, .medium)).foregroundColor(EventEditorTokens.placeholder)
    }

    var body: some View {
        Group {
            if multiline {
                TextField("", text: $text, prompt: prompt, axis: .vertical)
                    .lineLimit(3...8)
                    .frame(minHeight: 52, alignment: .topLeading)
            } else {
                TextField("", text: $text, prompt: prompt)
            }
        }
        .font(FMW.ui(15, .semibold))
        .foregroundStyle(FMW.ink)
        .tint(FMW.pine)
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMW.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(FMW.line, lineWidth: 1.5))
    }
}

private struct EventEditorSmallInput: View {
    let placeholder: String
    @Binding var text: String
    var body: some View {
        TextField("", text: $text,
                  prompt: Text(placeholder).font(FMW.ui(13.5, .medium)).foregroundColor(EventEditorTokens.placeholder))
            .font(FMW.ui(13.5, .semibold))
            .foregroundStyle(FMW.ink)
            .tint(FMW.pine)
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FMW.cream, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(FMW.line, lineWidth: 1.5))
    }
}

// MARK: - Chips

private struct EventEditorChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(FMW.ui(13, .semibold))
                .foregroundStyle(isOn ? .white : FMW.pineDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isOn ? FMW.pine : FMW.paper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isOn ? FMW.pine : FMW.lineMint, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

/// Single-select chipset bound to one value.
private struct EventEditorChipset: View {
    let options: [String]
    @Binding var selection: String
    var body: some View {
        EventEditorFlow {
            ForEach(options, id: \.self) { option in
                EventEditorChip(label: option, isOn: selection == option) { selection = option }
            }
        }
        .padding(.top, 6)
    }
}

// MARK: - Paid item card

private struct EventEditorItemCard: View {
    let item: PaidItem
    let onDelete: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 10) {
                Text(item.name)
                    .font(FMW.ui(14.5, .bold))
                    .foregroundStyle(FMW.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.price)
                    .font(FMW.ui(14.5, .heavy))
                    .monospacedDigit()
                    .foregroundStyle(FMW.pineDeep)
                Button(action: onDelete) {
                    Text("×")
                        .font(FMW.ui(16, .heavy))
                        .foregroundStyle(EventEditorTokens.del)
                        .padding(.horizontal, 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(item.name)")
            }
            Text(item.sub)
                .font(FMW.ui(12))
                .foregroundStyle(FMW.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMW.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(FMW.line, lineWidth: 1.5))
        .shadow(color: FMW.ink.opacity(0.14), radius: 10, x: 0, y: 6)
    }
}

// MARK: - Footer (Save draft · Publish)

private struct EventEditorFooter: View {
    var saving: Bool = false
    let onDraft: () -> Void
    let onPublish: () -> Void
    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 10
            let draftWidth = (geo.size.width - gap) * 0.4
            HStack(spacing: gap) {
                Button(action: onDraft) {
                    Text("Save draft")
                        .font(FMW.ui(15, .bold))
                        .foregroundStyle(FMW.pineDeep)
                        .frame(width: draftWidth, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(FMW.lineMint, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onPublish) {
                    HStack(spacing: 8) {
                        if saving { ProgressView().tint(.white) }
                        Text(saving ? "Publishing…" : "Publish event")
                            .font(FMW.ui(15, .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(FMW.pine, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: FMW.pine.opacity(0.45), radius: 12, x: 0, y: 10)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 50)
        .disabled(saving)
    }
}

// MARK: - Wrapping flow layout (chipsets)

private struct EventEditorFlow: Layout {
    var hSpacing: CGFloat = 8
    var vSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + vSpacing
                rowHeight = 0
            }
            x += size.width + hSpacing
            rowHeight = max(rowHeight, size.height)
            maxRowWidth = max(maxRowWidth, x - hSpacing)
        }
        let width = maxWidth == .infinity ? maxRowWidth : min(maxWidth, maxRowWidth)
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > bounds.minX && (x - bounds.minX) + size.width > maxWidth {
                x = bounds.minX
                y += rowHeight + vSpacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + hSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Screen-local tokens (shades sampled from prototype, not in DesignTokens)

private enum EventEditorTokens {
    static let placeholder = Color(hex: 0xB8B2A3)   // .tinput::placeholder
    static let del         = Color(hex: 0xC0B8A6)   // .itemcard .del

    // detail-hero inline gradient: linear-gradient(165deg,#EAF4EC,#DCEEDF 60%,#FDECD2)
    static let hero = LinearGradient(
        stops: [
            .init(color: Color(hex: 0xEAF4EC), location: 0.0),
            .init(color: Color(hex: 0xDCEEDF), location: 0.6),
            .init(color: Color(hex: 0xFDECD2), location: 1.0)
        ],
        startPoint: .topTrailing, endPoint: .bottomLeading
    )
}

#Preview {
    EventEditorView()
}
