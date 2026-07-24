import SwiftUI

/// Home — the neighborhood hub (spec screen #2 / IA "Home"): a sunny brand hero,
/// the next-event ticket stub, the module grid (Events · Pavilion · Directory ·
/// Pool & Tennis, all live), and a notice. New modules surface here — never a new tab.
/// Built to match Design/prototype.html (data-screen="home").
struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeroCard()
                    .padding(.horizontal, 12)
                    .padding(.top, 6)

                TicketStub()
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                SectionHeader(title: "What’s in the neighborhood")
                    .padding(.horizontal, 18)
                    .padding(.top, 22)
                    .padding(.bottom, 10)

                ModuleGrid()
                    .padding(.horizontal, 18)

                NoticeCard()
                    .padding(.horizontal, 18)
                    .padding(.top, 14)

                Color.clear.frame(height: 26)
            }
        }
        .scrollIndicators(.hidden)
        .background(FMW.cream.ignoresSafeArea())
    }
}

// MARK: - Hero

private struct HeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Fox Mill Woods")
                        .font(FMW.display(20, .heavy))
                        .foregroundStyle(FMW.pineDeep)
                    Text("CONNECT · PLAY · GROW")
                        .font(FMW.ui(9.5, .bold))
                        .tracking(2.0)
                        .foregroundStyle(FMW.sun)
                }
                Spacer(minLength: 8)
                FMWPill(text: "Summer ’26", bg: FMW.pillSunBg, fg: FMW.pillSunFg)
            }

            HStack(spacing: 7) {
                Text("◆").font(.system(size: 8)).foregroundStyle(FMW.sun)
                Text("HAPPENING TODAY")
                    .font(FMW.ui(11, .bold))
                    .tracking(1.6)
                    .foregroundStyle(FMW.sun)
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                FMW.heroGradient
                FMW.sunwash
                Treeline().fill(FMW.pine.opacity(0.14)).frame(height: 34)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(FMW.sun.opacity(0.22), lineWidth: 1)
        )
    }
}

// MARK: - Next-event ticket stub

private struct TicketStub: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("THE CROOKED FOX COLLECTIVE")
                    .font(FMW.ui(11, .bold))
                    .tracking(1.2)
                    .foregroundStyle(FMW.sun)
                Text("Float Night at the Pool")
                    .font(FMW.display(22, .bold))
                    .foregroundStyle(FMW.ink)
                    .padding(.top, 5)
                HStack(spacing: 12) {
                    meta("calendar", "Wed, Jul 22 · 5:00 PM")
                    meta("mappin.and.ellipse", "Black Fir Ct Pool")
                }
                .padding(.top, 9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Perforation()
                .frame(height: 20)
                .padding(.horizontal, 14)

            HStack {
                FMWPill(text: "● Free · RSVP", bg: FMW.pillFreeBg, fg: FMW.pillFreeFg)
                Spacer(minLength: 8)
                Text("RSVP →")
                    .font(FMW.ui(13.5, .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(FMW.pine, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(FMW.paper)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: FMW.ink.opacity(0.22), radius: 18, x: 0, y: 12)
    }

    private func meta(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(FMW.pine)
            Text(text)
                .font(FMW.ui(13, .medium))
                .foregroundStyle(FMW.pineDeep)
        }
    }
}

/// Dashed perforation with the two round notches bitten out of the ticket's sides.
private struct Perforation: View {
    var body: some View {
        Rectangle()
            .fill(FMW.line)
            .frame(height: 2)
            .frame(maxHeight: .infinity, alignment: .center)
            .overlay(alignment: .center) {
                Line()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(FMW.cream)
            }
            .overlay(alignment: .leading) { notch.offset(x: -24) }
            .overlay(alignment: .trailing) { notch.offset(x: 24) }
    }
    private var notch: some View {
        Circle()
            .fill(FMW.cream)
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(FMW.line.opacity(0.7), lineWidth: 1))
    }
}

private struct Line: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: r.midY))
        p.addLine(to: CGPoint(x: r.width, y: r.midY))
        return p
    }
}

// MARK: - Module grid

private struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack {
            Text(title).font(FMW.display(18, .semibold)).foregroundStyle(FMW.ink)
            Spacer()
        }
    }
}

private struct ModuleGrid: View {
    var body: some View {
        Grid(horizontalSpacing: 11, verticalSpacing: 11) {
            GridRow {
                ModuleTile(title: "Events", subtitle: "RSVP & pay for socials", symbol: "calendar", style: .pine)
                ModuleTile(title: "Rent the Pavilion", subtitle: "Book an open date", symbol: "house.fill", style: .sun)
            }
            GridRow {
                ModuleTile(title: "Directory", subtitle: "Find a neighbor", symbol: "person.2.fill", style: .pine)
                ModuleTile(title: "Pool & Tennis", subtitle: "Today’s hours", symbol: "water.waves", style: .sun)
            }
        }
    }
}

private struct ModuleTile: View {
    enum Style { case pine, sun }
    let title: String
    let subtitle: String
    let symbol: String
    let style: Style

    private var ink: Color { style == .pine ? FMW.pineDeep : FMW.rentInk }
    private var accent: Color { style == .pine ? FMW.pine : FMW.sun }
    private var fill: LinearGradient { style == .pine ? FMW.eventsTile : FMW.rentTile }
    private var badgeFg: Color { style == .pine ? .white : FMW.sunInk }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(accent)
            Spacer(minLength: 10)
            Text(title).font(FMW.display(16, .semibold)).foregroundStyle(ink)
            Text(subtitle)
                .font(FMW.ui(11.5, .medium))
                .foregroundStyle(ink.opacity(0.75))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(14)
        .background(fill)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Text("LIVE")
                .font(FMW.ui(9.5, .heavy))
                .tracking(0.5)
                .foregroundStyle(badgeFg)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(accent, in: Capsule())
                .padding(11)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle). Live.")
    }
}

// MARK: - Notice

private struct NoticeCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(FMW.pine)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pool closes at 4 PM Saturday")
                    .font(FMW.ui(13.5, .bold))
                    .foregroundStyle(FMW.ink)
                Text("Setup for the Relay Carnival. Deck reopens Sunday at 10 AM.")
                    .font(FMW.ui(12.5))
                    .foregroundStyle(FMW.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FMW.mint)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(FMW.lineMint, lineWidth: 1)
        )
    }
}

#Preview {
    HomeView()
}
