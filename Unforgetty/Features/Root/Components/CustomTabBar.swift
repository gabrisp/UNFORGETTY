//
//  CustomTabBar.swift
//  InstagramStyleTabBar
//
//  Created by Balaji Venkatesh on 24/07/26.
//

import SwiftUI

protocol CustomTabBarItem: CaseIterable, Hashable {
    var title: String { get }
}

extension View {
    @ViewBuilder
    func hideNativeTabBar() -> some View {
        self
            .toolbarVisibility(.hidden, for: .tabBar)
    }
}

extension ScrollView {
    @ViewBuilder
    func adoptForIGTabBar(_ progress: Binding<CGFloat>) -> some View {
        self
            .modifier(IGTabBarViewModifier(progress: progress))
    }
}

struct CustomTabBar<Value: CustomTabBarItem>: UIViewRepresentable {
    @Binding var selection: Value
    var selectedTextColor: Color = .primary
    var normalTextColor: Color = .secondary
    var selectedTintColor: Color = .gray.opacity(0.25)
    var onInteraction: (Value) -> Void = { _ in }

    init(
        selection: Binding<Value>,
        selectedTextColor: Color = .primary,
        normalTextColor: Color = .secondary,
        selectedTintColor: Color = .gray.opacity(0.25),
        onInteraction: @escaping (Value) -> Void = { _ in }
    ) {
        _selection = selection
        self.selectedTextColor = selectedTextColor
        self.normalTextColor = normalTextColor
        self.selectedTintColor = selectedTintColor
        self.onInteraction = onInteraction
    }

    func makeUIView(context: Context) -> CustomSegmentedControl {
        let tabs = Array(Value.allCases)
        let control = CustomSegmentedControl(items: tabs.map(\.title))
        control.selectedSegmentIndex = tabs.firstIndex(of: selection) ?? 0
        control.selectedSegmentTintColor = UIColor(selectedTintColor)
        control.backgroundColor = .clear
        control.tintColor = .clear
        control.configureTransparentBackground()
        control.setTitleTextAttributes([
            .foregroundColor: UIColor(selectedTextColor),
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ], for: .selected)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor(normalTextColor),
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ], for: .normal)
        control.addTarget(
            context.coordinator,
            action: #selector(context.coordinator.valueChanged(_:)),
            for: .valueChanged
        )

        return control
    }

    func updateUIView(_ uiView: CustomSegmentedControl, context: Context) {
        let selectedIndex = Array(Value.allCases).firstIndex(of: selection) ?? 0
        if uiView.selectedSegmentIndex != selectedIndex {
            uiView.selectedSegmentIndex = selectedIndex
        }

        uiView.selectedSegmentTintColor = UIColor(selectedTintColor)
        uiView.setTitleTextAttributes([
            .foregroundColor: UIColor(selectedTextColor),
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ], for: .selected)
        uiView.setTitleTextAttributes([
            .foregroundColor: UIColor(normalTextColor),
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ], for: .normal)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CustomSegmentedControl, context: Context) -> CGSize? {
        .init(
            width: proposal.width ?? CGFloat(Array(Value.allCases).count) * 150,
            height: 50
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject {
        var parent: CustomTabBar

        init(parent: CustomTabBar) {
            self.parent = parent
        }

        @objc
        func valueChanged(_ sender: UISegmentedControl) {
            let tabs = Array(Value.allCases)
            guard tabs.indices.contains(sender.selectedSegmentIndex) else { return }
            let tab = tabs[sender.selectedSegmentIndex]
            parent.selection = tab
            parent.onInteraction(tab)
        }
    }
}

struct IGStyleTabBar<Value: CaseIterable>: UIViewRepresentable where Value: Hashable {
    @Binding var selection: Value
    var symbolImage: (Value) -> UIImage
    var onInteraction: () -> ()
    func makeUIView(context: Context) -> CustomSegmentedControl {
        let images = Array(Value.allCases).compactMap(symbolImage)
        let control = CustomSegmentedControl(items: images)
        control.selectedSegmentIndex = Array(Value.allCases).firstIndex(of: selection) ?? 0
        control.selectedSegmentTintColor = UIColor(Color.gray.opacity(0.25))
        control.backgroundColor = .clear
        control.tintColor = .clear
        control.configureTransparentBackground()
        control.addTarget(
            context.coordinator,
            action: #selector(context.coordinator.valueChanged(_:)),
            for: .valueChanged
        )

        control.onTouchBegan = onInteraction

        return control
    }

    func updateUIView(_ uiView: CustomSegmentedControl, context: Context) {
        /// Updating Control, if there is an outside update
        let selectedIndex = Array(Value.allCases).firstIndex(of: selection) ?? 0
        if uiView.selectedSegmentIndex != selectedIndex {
            uiView.selectedSegmentIndex = selectedIndex
        }
    }

    /// Custom Sizing!
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CustomSegmentedControl, context: Context) -> CGSize? {
        return .init(
            width: CGFloat(Array(Value.allCases).count) * 80,
            height: 50
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject {
        var parent: IGStyleTabBar
        init(parent: IGStyleTabBar) {
            self.parent = parent
        }

        @objc
        func valueChanged(_ sender: UISegmentedControl) {
            parent.selection = Array(Value.allCases)[sender.selectedSegmentIndex]
        }
    }
}

class CustomSegmentedControl: UISegmentedControl {
    var onTouchBegan: (() -> Void)?

    func configureTransparentBackground() {
        let clearImage = UIImage.clearSegmentBackground
        setBackgroundImage(clearImage, for: .normal, barMetrics: .default)
        setBackgroundImage(clearImage, for: .selected, barMetrics: .default)
        setBackgroundImage(clearImage, for: .highlighted, barMetrics: .default)
        setDividerImage(clearImage, forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
        setDividerImage(clearImage, forLeftSegmentState: .selected, rightSegmentState: .normal, barMetrics: .default)
        setDividerImage(clearImage, forLeftSegmentState: .normal, rightSegmentState: .selected, barMetrics: .default)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        onTouchBegan?()
    }
}

private extension UIImage {
    static var clearSegmentBackground: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 1, height: 32)).image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 32))
        }
    }
}

fileprivate struct IGTabBarViewModifier: ViewModifier {
    /// 0- means expanded
    /// 1- means minimized
    @Binding var progress: CGFloat
    /// View Properties
    @GestureState private var isDragging: Bool = false
    @State private var isScrolledUp: Bool?
    @State private var shiftOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isLargerContent: Bool = false
    @State private var scrollPhase: ScrollPhase = .idle
    func body(content: Content) -> some View {
        content
            /// If you add this modifier, then no need for hide tab bar modifier to be added!
            .toolbarVisibility(.hidden, for: .tabBar)
            /// Adjusting Tab Bar Height!
            .safeAreaPadding(.bottom, 50)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .scrollView)
                    .updating($isDragging) { _, out, _ in
                        out = true
                    }.onEnded { value in
                        guard scrollPhase != .idle else { return }
                        /// NOTE: To decrease velocity increase the number from 5 to something higher!
                        let velocity = -value.velocity.height / 5
                        let resultOffset = scrollOffset + velocity
                        let rawProgress = (resultOffset - shiftOffset) / distance
                        let clampedProgress = max(0, min(1, rawProgress))

                        withAnimation(animation) {
                            self.progress = resultOffset > (distance / 2) && isLargerContent ? (clampedProgress > 0.5 ? 1 : 0) : 0
                        }

                        isScrolledUp = nil
                        /// Adjusting Shift Offset accordingly!
                        shiftOffset = scrollOffset - (progress * distance)
                    }
            )
            .onScrollPhaseChange({ oldPhase, newPhase in
                scrollPhase = newPhase
            })
            .onScrollGeometryChange(for: CGFloat.self, of: {
                $0.contentSize.height - $0.containerSize.height
            }, action: { oldValue, newValue in
                isLargerContent = newValue > 0
            })
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y + $0.contentInsets.top
            } action: { oldValue, newValue in
                guard isDragging else { return }
                scrollOffset = newValue
                let isScrolledUp = oldValue < newValue

                if self.isScrolledUp != isScrolledUp {
                    self.isScrolledUp = isScrolledUp
                    /// Store Shift Offset
                    self.shiftOffset = newValue - (progress * distance)
                }

                let rawProgress = (newValue - shiftOffset) / distance
                let clampedProgress = max(0, min(1, rawProgress))

                withAnimation(animation) {
                    self.progress = clampedProgress
                }
            }
    }

    /// Update these values according to your own needs!
    private var distance: CGFloat {
        return 100
    }

    private var animation: Animation {
        .interpolatingSpring(duration: 0.25, bounce: 0, initialVelocity: 0)
    }
}
