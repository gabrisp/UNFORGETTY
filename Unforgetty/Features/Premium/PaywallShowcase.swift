import SwiftUI

struct PaywallShowcaseCard: Identifiable {
    let id = UUID()
    let text: String
    let style: ActivityStyle
}

enum PaywallShowcase {
    static let cards: [PaywallShowcaseCard] = [
        card("Take your vitamins 💊", background: "1C1C28", textHex: "FFFFFF", font: .rounded, alignment: .leading),
        card("Gym at 6:30pm 🏋️", gradientStart: "FF6B6B", gradientEnd: "FFA36B", angle: 120, textHex: "1A0F0A", font: .rounded, alignment: .center),
        card("Call mom", background: "0F2A24", textHex: "9CFFE0", font: .serif, alignment: .leading),
        card("Study session — Chapter 4", gradientStart: "3A1C71", gradientEnd: "6E44FF", angle: 60, textHex: "FFFFFF", font: .monospaced, alignment: .leading),
        card("Water the plants 🌱", background: "16342A", textHex: "B7F5C9", font: .rounded, alignment: .center),
        card("Team standup in 10 min", gradientStart: "0F2027", gradientEnd: "2C5364", angle: 135, textHex: "E6FBFF", font: .rounded, alignment: .leading),
        card("Read 20 pages 📖", background: "2B2113", textHex: "F3D9A6", font: .serif, alignment: .leading),
        card("Meditate 10 min 🧘", gradientStart: "FDCBF1", gradientEnd: "E6DEE9", angle: 90, textHex: "3A2A3D", font: .rounded, alignment: .center),
        card("Pay rent reminder", background: "1F1300", textHex: "FFD27D", font: .monospaced, alignment: .leading),
        card("Walk the dog 🐕", gradientStart: "F6D365", gradientEnd: "FDA085", angle: 45, textHex: "3A2200", font: .rounded, alignment: .center)
    ]

    private static func card(
        _ text: String,
        background: String,
        textHex: String,
        font: ActivityStyle.FontChoice,
        alignment: ActivityStyle.TextAlignmentChoice
    ) -> PaywallShowcaseCard {
        var style = ActivityStyle()
        style.backgroundMode = .plain
        style.backgroundHex = background
        style.textHex = textHex
        style.font = font
        style.alignment = alignment
        return PaywallShowcaseCard(text: text, style: style)
    }

    private static func card(
        _ text: String,
        gradientStart: String,
        gradientEnd: String,
        angle: Double,
        textHex: String,
        font: ActivityStyle.FontChoice,
        alignment: ActivityStyle.TextAlignmentChoice
    ) -> PaywallShowcaseCard {
        var style = ActivityStyle()
        style.backgroundMode = .gradient
        style.gradientStartHex = gradientStart
        style.gradientEndHex = gradientEnd
        style.gradientAngle = angle
        style.textHex = textHex
        style.font = font
        style.alignment = alignment
        return PaywallShowcaseCard(text: text, style: style)
    }
}

struct PaywallMarqueeShowcase: View {
    private let cardHeight: CGFloat = 160
    private let horizontalPadding: CGFloat = 16
    private let spacing: CGFloat = 14

    var body: some View {
        GeometryReader { geometry in
            // Matches the real Live Activity's own dimensions (160pt tall, full screen width
            // minus the standard 16pt side padding) instead of an arbitrary small card size.
            let cardWidth = geometry.size.width - (horizontalPadding * 2)

            VStack(spacing: spacing) {
                MarqueeRow(
                    cards: PaywallShowcase.cards,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    spacing: spacing,
                    speed: 24,
                    reversed: false,
                    leadingPadding: 0
                )
                MarqueeRow(
                    cards: Array(PaywallShowcase.cards.rotated(by: 5)),
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

    var body: some View {
        Text(card.text)
            .font(.system(size: 15, weight: .semibold, design: card.style.fontDesign))
            .foregroundStyle(Color(hex: card.style.textHex))
            .multilineTextAlignment(card.style.textAlignment)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: card.style.horizontalAlignment, vertical: .center))
            .padding(14)
            .activityCardBackground(style: card.style, kind: .note, cornerRadius: 20)
    }
}

private extension Array {
    func rotated(by amount: Int) -> [Element] {
        guard !isEmpty else { return self }
        let offset = ((amount % count) + count) % count
        return Array(self[offset...] + self[..<offset])
    }
}
