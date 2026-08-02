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
        note("Water the plants 🌱", background: "16342A", textHex: "B7F5C9", font: .rounded, alignment: .center)
    ]

    static let cardsRowTwo: [PaywallShowcaseCard] = [
        note("Team standup in 10 min", gradientStart: "0F2027", gradientEnd: "2C5364", angle: 135, textHex: "E6FBFF", font: .rounded, alignment: .leading),
        checklist(["Read 20 pages 📖", "Meditate 10 min"], background: "2B2113", textHex: "F3D9A6", font: .serif),
        note("Meditate 10 min 🧘", gradientStart: "FDCBF1", gradientEnd: "E6DEE9", angle: 90, textHex: "3A2A3D", font: .rounded, alignment: .center),
        note("Pay rent reminder", background: "1F1300", textHex: "FFD27D", font: .monospaced, alignment: .leading),
        note("Walk the dog 🐕", gradientStart: "F6D365", gradientEnd: "FDA085", angle: 45, textHex: "3A2200", font: .rounded, alignment: .center)
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
}

struct PaywallMarqueeShowcase: View {
    // A note card's single line of text fits comfortably well under 90, but a checklist card's row
    // height has a fixed 32pt-per-row floor (`ActivityContentView.checkbox`, shared with the real
    // Live Activity, not something to shrink just for this compact showcase) — two rows plus their
    // spacing and this card's own padding need ~108pt to actually fit without `.clipped()` cutting
    // a row off.
    private let cardHeight: CGFloat = 120
    private let horizontalPadding: CGFloat = 16
    private let spacing: CGFloat = 14

    // Reads the actual device screen width directly rather than a GeometryReader nested inside
    // a parent that pads and then un-pads itself with a hardcoded negative value — that only
    // works if the guess exactly matches the parent's real (system-default, not fixed) padding,
    // which is fragile. This is exact regardless of what the parent around it does. Sized as a
    // fraction of the screen (not full-width minus padding) so more than one card is visible at
    // once — a marquee of one full-width card per "row position" doesn't read as a marquee.
    private var cardWidth: CGFloat {
        #if canImport(UIKit)
        UIScreen.main.bounds.width * 0.42
        #else
        400 * 0.42
        #endif
    }

    var body: some View {
        VStack(spacing: spacing) {
            MarqueeRow(
                cards: PaywallShowcase.cardsRowOne,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                spacing: spacing,
                speed: 24,
                reversed: false,
                leadingPadding: 0
            )
            MarqueeRow(
                cards: PaywallShowcase.cardsRowTwo,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                spacing: spacing,
                speed: 20,
                reversed: true,
                // Half a card-width (plus its spacing) so this row's cards sit centered on the
                // seam between two cards in the row above — a staggered, interlocking look.
                leadingPadding: (cardWidth + spacing) / 2
            )
        }
        .frame(height: cardHeight * 2 + spacing)
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

private struct MarqueeRow: View {
    let cards: [PaywallShowcaseCard]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let spacing: CGFloat
    let speed: Double
    let reversed: Bool
    let leadingPadding: CGFloat

    private var setWidth: CGFloat { (cardWidth + spacing) * CGFloat(cards.count) }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let distance = CGFloat(elapsed * speed).truncatingRemainder(dividingBy: setWidth)
            let offset = reversed ? distance - setWidth : -distance

            HStack(spacing: spacing) {
                ForEach(0..<3, id: \.self) { setIndex in
                    ForEach(cards) { card in
                        PaywallShowcaseCardView(card: card)
                            .frame(width: cardWidth, height: cardHeight)
                    }
                }
            }
            .padding(.leading, leadingPadding)
            .offset(x: offset)
        }
        .frame(height: cardHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }
}

private struct PaywallShowcaseCardView: View {
    let card: PaywallShowcaseCard
    @State private var draft: LiveActivityDraft

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
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .activityCardBackground(style: draft.style, kind: draft.kind, cornerRadius: 20)
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

