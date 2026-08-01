import SwiftUI

struct GlassSegmentedControl: View {
    var config: Config = .init()
    @Binding var selection: Int
    @Binding var tabs: [Self.Tab]
    @State private var activeIndex: Int?
    @State private var scrollPosition: ScrollPosition = .init()
    @State private var scrollPhase: ScrollPhase = .idle

    var body: some View {
        GeometryReader { proxy in
            let containerSize = proxy.size
            let activeSize = tabs[activeIndex ?? 0].viewSize

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach($tabs) { $tab in
                        Text(tab.title)
                            .font(.system(size: 18))
                            .padding(.horizontal, config.refractionDepth + 3)
                            .frame(height: containerSize.height)
                            .onGeometryChange(for: CGSize.self) {
                                $0.size
                            } action: { newValue in
                                tab.viewSize = newValue
                            }
                            .contentShape(.rect)
                            .onTapGesture {
                                if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
                                    selection = index
                                }
                            }
                    }
                }
                .overlay {
                    HStack(spacing: 0) {
                        ForEach($tabs) { $tab in
                            Text(tab.title)
                                .font(.system(size: 18))
                                .foregroundStyle(config.tint)
                                .padding(.horizontal, config.refractionDepth + 3)
                                .frame(height: containerSize.height)
                        }
                    }
                    .mask(alignment: .leading) {
                        Capsule()
                            .frame(width: activeSize.width, height: activeSize.height)
                            .visualEffect { content, proxy in
                                let midX = proxy.frame(in: .scrollView).midX

                                return content
                                    .offset(x: -midX)
                            }
                    }
                    .allowsHitTesting(false)
                }
                .visualEffect { [config] content, proxy in
                    let rect = proxy.frame(in: .scrollView)
                    let minX = rect.minX + (activeSize.width / 2)

                    return content
                        .layerEffect(
                            ShaderLibrary.liquidLens(
                                .float2(activeSize),
                                .float(-minX),
                                .float(config.refractionAmount),
                                .float(config.refractionDepth)
                            ),
                            maxSampleOffset: .init(width: 200, height: 100)
                        )
                }
                .background(alignment: .leading) {
                    ZStack {
                        if #available(iOS 26, *) {
                            Capsule()
                                .fill(.clear)
                                .frame(width: activeSize.width, height: activeSize.height)
                                .glassEffect(.regular, in: .capsule)
                        } else {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .frame(width: activeSize.width, height: activeSize.height)
                        }
                    }
                    .allowsHitTesting(false)
                    .visualEffect { content, proxy in
                        let midX = proxy.frame(in: .scrollView).midX

                        return content
                            .offset(x: -midX)
                    }
                }
                .animation(
                    .interactiveSpring(response: 0.35, dampingFraction: 0.3, blendDuration: 0.4),
                    value: activeIndex
                )
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(.horizontal, containerSize.width / 2)
            .scrollTargetBehavior(GlassSegmentedScrollTarget(tabs: $tabs))
            .scrollPosition($scrollPosition, anchor: .center)
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.x + $0.contentInsets.leading
            } action: { _, newValue in
                if let index = tabs.closestSnapPointIndex(newValue), activeIndex != nil {
                    activeIndex = index
                    if scrollPhase != .animating {
                        selection = index
                    }
                }
            }
            .onScrollPhaseChange { _, newPhase in
                scrollPhase = newPhase
            }
        }
        .frame(height: 50)
        .task {
            if activeIndex == nil {
                let cappedIndex = max(min(selection, tabs.count - 1), 0)
                selection = cappedIndex
                activeIndex = cappedIndex
                scrollPosition.scrollTo(x: tabs.snapPoints[cappedIndex])
            }
        }
        .onChange(of: selection) { _, newValue in
            if activeIndex != newValue {
                let cappedIndex = max(min(selection, tabs.count - 1), 0)
                activeIndex = cappedIndex
                withAnimation(config.selectionChangeAnimation) {
                    scrollPosition.scrollTo(x: tabs.snapPoints[cappedIndex])
                }
            }
        }
        .allowsHitTesting(scrollPhase != .animating)
        .sensoryFeedback(.selection, trigger: selection)
    }

    struct Config {
        var tint: Color = .yellow
        var refractionAmount: CGFloat = 10
        var refractionDepth: CGFloat = 17
        var selectionChangeAnimation: Animation? = .none
    }

    struct Tab: Identifiable {
        var title: String
        fileprivate var viewSize: CGSize = .zero

        init(title: String) {
            self.title = title
        }

        var id: String { title }
    }
}

private extension [GlassSegmentedControl.Tab] {
    var snapPoints: [CGFloat] {
        var snapPoints: [CGFloat] = []
        var x: CGFloat = 0

        for tab in self {
            snapPoints.append(x + tab.viewSize.width / 2)
            x += tab.viewSize.width
        }

        return snapPoints
    }

    func closestSnapPointIndex(_ offset: CGFloat) -> Int? {
        if let (index, _) = snapPoints.enumerated().min(by: {
            abs($0.element - offset) < abs($1.element - offset)
        }) {
            return index
        }

        return nil
    }
}

private struct GlassSegmentedScrollTarget: ScrollTargetBehavior {
    @Binding var tabs: [GlassSegmentedControl.Tab]

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let offset = target.rect.origin.x
        target.rect.origin.x = tabs.snapPoints.min(by: {
            abs($0 - offset) < abs($1 - offset)
        }) ?? offset
    }

    func properties(context: PropertiesContext) -> Properties {
        var properties = Properties()
        properties.limitsScrolls = true
        return properties
    }
}
