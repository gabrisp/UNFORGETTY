import SwiftUI
import UIKit

enum CutoutAccessoryPadding {
    case auto
    case none
    case custom(
        cutout: (CGFloat) -> CGFloat,
        content: (CGFloat) -> CGFloat,
        vertical: (CGFloat) -> CGFloat = { $0 * 0.05 }
    )
}

struct CutoutAccessoryView<LeadingContent: View, TrailingContent: View>: View {
    @Environment(\.notchOverrides) private var environmentOverrides

    let padding: CutoutAccessoryPadding
    let leadingContent: LeadingContent
    let trailingContent: TrailingContent

    init(
        padding: CutoutAccessoryPadding = .auto,
        @ViewBuilder leadingContent: () -> LeadingContent,
        @ViewBuilder trailingContent: () -> TrailingContent
    ) {
        self.padding = padding
        self.leadingContent = leadingContent()
        self.trailingContent = trailingContent()
    }

    var body: some View {
        GeometryReader { geometry in
            let statusBarHeight = geometry.safeAreaInsets.top
            let hasTopCutout = statusBarHeight > 40
            let exclusionRect = adjustedExclusionRect
            let exclusionWidth = exclusionRect?.width ?? (geometry.size.width - 180)
            let exclusionHeight = NotchMyProblem.exclusionRect?.height ?? 0
            let paddingValues = paddingValues(
                exclusionWidth: exclusionWidth,
                exclusionHeight: exclusionHeight
            )
            let topPadding = topPadding(
                hasTopCutout: hasTopCutout,
                exclusionHeight: exclusionHeight
            )

            HStack(spacing: 0) {
                leadingContent
                    .frame(maxWidth: .infinity, alignment: hasTopCutout ? .center : .leading)

                if exclusionWidth > 0 {
                    Color.clear
                        .frame(width: exclusionWidth)
                        .padding(.horizontal, paddingValues.cutout)
                }

                trailingContent
                    .frame(maxWidth: .infinity, alignment: hasTopCutout ? .center : .trailing)
            }
            .padding(.vertical, paddingValues.vertical)
            .frame(height: hasTopCutout ? (NotchMyProblem.exclusionRect?.height ?? statusBarHeight) : 30)
            .padding(.top, topPadding)
            .padding(.horizontal, hasTopCutout ? paddingValues.content : 5)
            .ignoresSafeArea()
        }
        .allowsHitTesting(true)
    }

    private var adjustedExclusionRect: CGRect? {
        if let environmentOverrides {
            NotchMyProblem.shared.adjustedExclusionRect(using: environmentOverrides)
        } else {
            NotchMyProblem.shared.adjustedExclusionRect
        }
    }

    private func paddingValues(exclusionWidth: CGFloat, exclusionHeight: CGFloat) -> (cutout: CGFloat, content: CGFloat, vertical: CGFloat) {
        switch padding {
        case .auto:
            let cutoutPadding = max(5, min(20, 45 - (exclusionWidth * 0.18)))
            let contentPadding = max(2, min(40, 85 - (exclusionWidth * 0.35)))
            let verticalPadding = exclusionHeight * 0.1
            return (cutoutPadding, contentPadding, verticalPadding)
        case .none:
            return (0, 0, 0)
        case .custom(let cutout, let content, let vertical):
            return (cutout(exclusionWidth), content(exclusionWidth), vertical(exclusionHeight))
        }
    }

    private func topPadding(hasTopCutout: Bool, exclusionHeight: CGFloat) -> CGFloat {
        let minY = NotchMyProblem.exclusionRect?.minY ?? (hasTopCutout ? 0 : 5)
        guard minY == 0 else { return minY }
        return hasTopCutout ? (exclusionHeight / 3) : 5
    }
}

struct DeviceOverride: Equatable, Hashable, Sendable {
    let modelIdentifier: String
    let scale: CGFloat
    let heightFactor: CGFloat
    let radius: CGFloat
    let isExactMatch: Bool

    init(
        modelIdentifier: String,
        scale: CGFloat = 1.0,
        heightFactor: CGFloat = 1.0,
        radius: CGFloat = 0,
        isExactMatch: Bool = true
    ) {
        self.modelIdentifier = modelIdentifier
        self.scale = scale
        self.heightFactor = heightFactor
        self.radius = radius
        self.isExactMatch = isExactMatch
    }

    static func series(prefix: String, scale: CGFloat, heightFactor: CGFloat, radius: CGFloat = 0) -> DeviceOverride {
        DeviceOverride(
            modelIdentifier: prefix,
            scale: scale,
            heightFactor: heightFactor,
            radius: radius,
            isExactMatch: false
        )
    }
}

@MainActor
final class NotchMyProblem {
    static let shared = NotchMyProblem()
    static var globalOverrides: [DeviceOverride] = [
        .series(prefix: "iPhone13", scale: 0.95, heightFactor: 1.0, radius: 27),
        .series(prefix: "iPhone14", scale: 0.75, heightFactor: 0.75, radius: 24),
        .series(prefix: "iPhone17,5", scale: 0.75, heightFactor: 0.75, radius: 24)
    ]
    static let exclusionRect: CGRect? = UIScreen.main.exclusionArea

    private let modelId = UIDevice.modelIdentifier
    var overrides: [DeviceOverride] = []

    private init() {}

    var adjustedExclusionRect: CGRect? {
        adjustedExclusionRect(using: overrides)
    }

    func adjustedExclusionRect(using customOverrides: [DeviceOverride]? = nil) -> CGRect? {
        guard let baseRect = Self.exclusionRect else { return nil }
        let effectiveOverrides = customOverrides ?? overrides

        if let override = effectiveOverrides.first(where: { $0.isExactMatch && $0.modelIdentifier == modelId }) {
            return applyOverride(to: baseRect, with: override)
        }

        if let override = effectiveOverrides.first(where: { !$0.isExactMatch && modelId.hasPrefix($0.modelIdentifier) }) {
            return applyOverride(to: baseRect, with: override)
        }

        if let override = Self.globalOverrides.first(where: { $0.isExactMatch && $0.modelIdentifier == modelId }) {
            return applyOverride(to: baseRect, with: override)
        }

        if let override = Self.globalOverrides.first(where: { !$0.isExactMatch && modelId.hasPrefix($0.modelIdentifier) }) {
            return applyOverride(to: baseRect, with: override)
        }

        return baseRect
    }

    private func applyOverride(to rect: CGRect, with override: DeviceOverride) -> CGRect {
        let scaledWidth = rect.width * override.scale
        let scaledHeight = rect.height * override.heightFactor
        let originX = rect.origin.x + (rect.width - scaledWidth) / 2
        return CGRect(x: originX, y: rect.origin.y, width: scaledWidth, height: scaledHeight)
    }
}

private extension UIScreen {
    @MainActor
    var exclusionArea: CGRect? {
        let modelId = UIDevice.modelIdentifier
        let isNotchedDevice = modelId.hasPrefix("iPhone") &&
            !["iPhone8", "iPhone9", "iPhone10,4", "iPhone10,5"].contains { modelId.hasPrefix($0) }
        guard isNotchedDevice else { return nil }

        let selectorName = ["Area", "exclusion", "_"].reversed().joined()
        let areaExclusionSelector = NSSelectorFromString(selectorName)
        guard responds(to: areaExclusionSelector) else { return nil }

        let implementation = method(for: areaExclusionSelector)
        let method = unsafeBitCast(
            implementation,
            to: (@convention(c) (AnyObject, Selector) -> AnyObject?).self
        )
        guard let object = method(self, areaExclusionSelector) else { return nil }

        let rectSelector = NSSelectorFromString("rect")
        guard object.responds(to: rectSelector) else { return nil }

        let rectImplementation = object.method(for: rectSelector)
        let rectMethod = unsafeBitCast(
            rectImplementation,
            to: (@convention(c) (AnyObject, Selector) -> CGRect).self
        )
        let rect = rectMethod(object, rectSelector)
        guard rect.width > 0, rect.height > 0, !rect.isInfinite, !rect.isNull else { return nil }
        return rect
    }
}

private extension UIDevice {
    @MainActor
    static let modelIdentifier: String = {
        if let simulatorModelIdentifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulatorModelIdentifier
        }

        var sysinfo = utsname()
        uname(&sysinfo)
        let machineData = Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN))
        return String(bytes: machineData, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters) ?? "unknown"
    }()
}

private struct NotchOverridesKey: EnvironmentKey {
    static let defaultValue: [DeviceOverride]? = nil
}

extension EnvironmentValues {
    var notchOverrides: [DeviceOverride]? {
        get { self[NotchOverridesKey.self] }
        set { self[NotchOverridesKey.self] = newValue }
    }
}

extension View {
    func notchOverrides(_ overrides: [DeviceOverride]) -> some View {
        environment(\.notchOverrides, overrides)
    }

    func notchOverride(_ override: DeviceOverride) -> some View {
        notchOverrides([override])
    }
}
