import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PaywallShowcaseCard: Identifiable {
    let id = UUID()
    let draft: LiveActivityDraft
}

enum PaywallShowcase {
    // Two genuinely distinct sets (not one array reordered) so the two marquee rows never show the
    // same card content, even offset.
    static let cardsRowOne: [PaywallShowcaseCard] = [
        note("Take your vitamins 💊", background: "1C1C28", textHex: "FFFFFF", font: .rounded, alignment: .leading),
        note("Gym at 6:30pm 🏋️", gradientStart: "FF6B6B", gradientEnd: "FFA36B", angle: 120, textHex: "1A0F0A", font: .rounded, alignment: .center),
        note("Call mom", background: "0F2A24", textHex: "9CFFE0", font: .serif, alignment: .leading),
        checklist(["Study session", "Chapter 4"], background: "3A1C71", textHex: "FFFFFF", font: .monospaced),
        music(imageName: "prev_music_1", title: "Las Jordan", artist: "TINI", album: "Cupido", background: "241528", textHex: "FFFFFF"),
        note("Water the plants 🌱", background: "16342A", textHex: "B7F5C9", font: .rounded, alignment: .center)
    ]

    static let cardsRowTwo: [PaywallShowcaseCard] = [
        note("Team standup in 10 min", gradientStart: "0F2027", gradientEnd: "2C5364", angle: 135, textHex: "E6FBFF", font: .rounded, alignment: .leading),
        checklist(["Read 20 pages 📖", "Meditate 10 min"], background: "2B2113", textHex: "F3D9A6", font: .serif),
        music(imageName: "prev_music_2", title: "Dealer", artist: "Corina Smith", album: "Menos Triste Más Mami", background: "1A1005", textHex: "FFD9A0"),
        note("Meditate 10 min 🧘", gradientStart: "FDCBF1", gradientEnd: "E6DEE9", angle: 90, textHex: "3A2A3D", font: .rounded, alignment: .center),
        note("Pay rent reminder", background: "1F1300", textHex: "FFD27D", font: .monospaced, alignment: .leading),
        note("Walk the dog 🐕", gradientStart: "F6D365", gradientEnd: "FDA085", angle: 45, textHex: "3A2200", font: .rounded, alignment: .center)
    ]

    static let cardsRowThree: [PaywallShowcaseCard] = [
        note("Flight boards at 9:40", background: "0B1F3A", textHex: "BFE1FF", font: .rounded, alignment: .leading),
        checklist(["Buy groceries 🛒", "Call the plumber"], background: "26331A", textHex: "E4FFB0", font: .rounded),
        note("Deep work block 🧠", gradientStart: "1D2B64", gradientEnd: "F8CDDA", angle: 100, textHex: "0B0F2E", font: .serif, alignment: .center),
        note("Passport expires soon", background: "2A0E0E", textHex: "FFB8B8", font: .monospaced, alignment: .leading),
        note("Birthday: Alex 🎂", gradientStart: "FFDEE9", gradientEnd: "B5FFFC", angle: 60, textHex: "1A1A2E", font: .rounded, alignment: .center)
    ]

    private static func note(
        _ text: String,
        background: String,
        textHex: String,
        font: ActivityStyle.FontChoice,
        alignment: ActivityStyle.TextAlignmentChoice
    ) -> PaywallShowcaseCard {
        var draft = LiveActivityDraft()
        draft.kind = .note
        draft.body = text
        draft.style.backgroundMode = .plain
        draft.style.backgroundHex = background
        draft.style.textHex = textHex
        draft.style.font = font
        draft.style.alignment = alignment
        draft.style.textSize = 26
        return PaywallShowcaseCard(draft: draft)
    }

    private static func note(
        _ text: String,
        gradientStart: String,
        gradientEnd: String,
        angle: Double,
        textHex: String,
        font: ActivityStyle.FontChoice,
        alignment: ActivityStyle.TextAlignmentChoice
    ) -> PaywallShowcaseCard {
        var draft = LiveActivityDraft()
        draft.kind = .note
        draft.body = text
        draft.style.backgroundMode = .gradient
        draft.style.gradientStartHex = gradientStart
        draft.style.gradientEndHex = gradientEnd
        draft.style.gradientAngle = angle
        draft.style.textHex = textHex
        draft.style.font = font
        draft.style.alignment = alignment
        draft.style.textSize = 26
        return PaywallShowcaseCard(draft: draft)
    }

    /// Rendered through the real `ActivityContentView` (like every other kind here), and wired up
    /// to actually toggle on tap in `PaywallShowcaseCardView` — the paywall should show the app
    /// doing something, not just a static mockup of it.
    private static func checklist(
        _ items: [String],
        background: String,
        textHex: String,
        font: ActivityStyle.FontChoice
    ) -> PaywallShowcaseCard {
        var draft = LiveActivityDraft()
        draft.kind = .check(.todoList)
        draft.checklistItems = items.map { ChecklistItem(text: $0) }
        draft.style.backgroundMode = .plain
        draft.style.backgroundHex = background
        draft.style.textHex = textHex
        draft.style.font = font
        draft.style.textSize = 17
        return PaywallShowcaseCard(draft: draft)
    }

    /// Album art ships as static bundled preview images (`prev_music_1`/`prev_music_2` in
    /// Assets.xcassets), loaded straight into `musicAlbumArtData` exactly like a real picked
    /// Spotify track's downloaded art would be — no network call needed for a showcase.
    private static func music(
        imageName: String,
        title: String,
        artist: String,
        album: String,
        background: String,
        textHex: String
    ) -> PaywallShowcaseCard {
        var draft = LiveActivityDraft()
        draft.kind = .music
        draft.musicTitle = title
        draft.musicArtist = artist
        draft.musicAlbum = album
        draft.style.backgroundMode = .plain
        draft.style.backgroundHex = background
        draft.style.textHex = textHex
        draft.style.textSize = 22
        #if canImport(UIKit)
        draft.musicAlbumArtData = UIImage(named: imageName)?.jpegData(compressionQuality: 0.9)
        #endif
        return PaywallShowcaseCard(draft: draft)
    }
}

struct PaywallMarqueeShowcase: View {
    private let spacing: CGFloat = 14
    // Separate from `spacing` (card-to-card, within a row) — this is specifically the gap
    // between the three stacked marquee rows.
    private let rowSpacing: CGFloat = 4

    var body: some View {
        VStack(spacing: rowSpacing) {
            MarqueeRow(
                cards: PaywallShowcase.cardsRowOne,
                spacing: spacing,
                speed: 24,
                reversed: false,
                leadingPadding: 0
            )
            MarqueeRow(
                cards: PaywallShowcase.cardsRowTwo,
                spacing: spacing,
                speed: 20,
                reversed: true,
                // A fixed stagger rather than half a card-width — cards now size to their own
                // content (see MarqueeRow's doc comment), so there's no single "card width" left to
                // derive a seam-aligned offset from. This is just a constant visual offset so the
                // two rows don't start perfectly aligned.
                leadingPadding: 48
            )
            MarqueeRow(
                cards: PaywallShowcase.cardsRowThree,
                spacing: spacing,
                speed: 27,
                reversed: false,
                leadingPadding: 24
            )
        }
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.08),
                    .init(color: .black, location: 0.92),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

/// Each card sizes to its own content (short note text is a narrow card, a checklist with two
/// longer items is a wider one) rather than a fixed width — so the infinite-scroll loop can't
/// assume `cardCount * fixedWidth` for its wraparound math anymore. Instead this measures one
/// full set's actual rendered width via `onGeometryChange` and uses that for the modulo/offset
/// calculation; until that first measurement lands, the row just sits still (no offset) rather
/// than guessing.
private struct MarqueeRow: View {
    let cards: [PaywallShowcaseCard]
    let spacing: CGFloat
    let speed: Double
    let reversed: Bool
    let leadingPadding: CGFloat

    // Headroom for the checklist cards' "TAP ME!" badge, which pops up above the card's own top
    // edge — without this, the row's own `.clipped()` below (needed to hide the scroll wraparound
    // seams) was cutting the badge off before it could be seen.
    private let badgeHeadroom: CGFloat = 26
    private var rowHeight: CGFloat { PaywallShowcaseCardView.cardHeight + badgeHeadroom }

    @State private var setWidth: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let distance = setWidth > 0 ? CGFloat(elapsed * speed).truncatingRemainder(dividingBy: setWidth) : 0
            let offset = reversed ? distance - setWidth : -distance

            HStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { setIndex in
                    cardSet
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { newValue in
                            if setIndex == 0 { setWidth = newValue }
                        }
                }
            }
            .padding(.leading, leadingPadding)
            .padding(.top, badgeHeadroom)
            .offset(x: offset)
        }
        // Card height is a fixed constant (see PaywallShowcaseCardView), so the row's height can
        // be too — no need to size it dynamically off content that's inside the `TimelineView`
        // closure. That closure re-evaluates on every display refresh (60Hz+) to drive the scroll
        // offset; letting SwiftUI re-measure an ideal *height* from content re-rendering that
        // often was making the enclosing ScrollView's content size unstable frame-to-frame,
        // which read as jittery/overscrolling even though nothing about the height actually
        // changes. A hard `.frame(height:)` outside the TimelineView removes that entirely.
        .frame(height: rowHeight, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private var cardSet: some View {
        HStack(spacing: spacing) {
            ForEach(cards) { card in
                PaywallShowcaseCardView(card: card)
            }
        }
    }
}

private struct PaywallShowcaseCardView: View {
    static let cardHeight: CGFloat = 160

    let card: PaywallShowcaseCard
    @State private var draft: LiveActivityDraft
    @State private var showsTapHint = false

    init(card: PaywallShowcaseCard) {
        self.card = card
        _draft = State(initialValue: card.draft)
    }

    var body: some View {
        ActivityContentView(
            draft: draft,
            allowsTapBlur: false,
            onToggleChecklistItem: checklistToggleHandler
        )
        // Collapses width back to intrinsic content size — ActivityContentView's internals use
        // `.frame(maxWidth: .infinity)` throughout (correct for its other, width-constrained call
        // sites), so without this the card would expand to fill whatever leftover space the
        // marquee's HStack offers instead of sizing to its own text/art. Height stays fixed at
        // 160 — the same height every real Live Activity card renders at elsewhere in the app
        // (see ActivityPreviewView's liveActivityMaxHeight) — rather than intrinsic, so the
        // showcase reads as "this is literally what your Live Activity looks like."
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 24)
        .frame(height: Self.cardHeight)
        .activityCardBackground(style: draft.style, kind: draft.kind, cornerRadius: 20)
        .overlay(alignment: .top) {
            if isInteractive {
                tapHintBadge
            }
        }
        .onAppear {
            guard isInteractive else { return }
            // Randomized per instance so the several checklist cards in the marquee (three
            // duplicated copies each, across three rows) don't all pop their badge at once —
            // staggered, it reads as "cards do this," not as a single jarring flash.
            let appearDelay = Double.random(in: 0.4...2.6)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(appearDelay)) {
                showsTapHint = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + appearDelay + 2.5) {
                withAnimation(.easeOut(duration: 0.35)) {
                    showsTapHint = false
                }
            }
        }
    }

    private var isInteractive: Bool { draft.kind == .check(.todoList) }

    /// A one-time hint (never re-triggers — `showsTapHint` only ever flips on then off once per
    /// card instance) nudging that the checklist cards, unlike the others in the marquee, actually
    /// respond to a tap.
    private var tapHintBadge: some View {
        Text("TAP ME!")
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.yellow, in: .capsule)
            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            .scaleEffect(showsTapHint ? 1 : 0.4)
            .opacity(showsTapHint ? 1 : 0)
            .offset(y: showsTapHint ? -16 : -6)
            .allowsHitTesting(false)
    }

    private var checklistToggleHandler: ((UUID) -> Void)? {
        guard draft.kind == .check(.todoList) else { return nil }
        return toggleChecklistItem
    }

    private func toggleChecklistItem(_ id: UUID) {
        guard let index = draft.checklistItems.firstIndex(where: { $0.id == id }) else { return }
        draft.checklistItems[index].isCompleted.toggle()
    }
}
