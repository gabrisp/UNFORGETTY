import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)
/// Icon-only toolbar button backed by a real `UIButton` — title is always nil, only an SF Symbol.
/// Used where a plain SwiftUI `Button`/`Image` inside a `ToolbarItem` doesn't give enough control
/// over sizing/tap target, and a UIKit-native control is wanted instead.
struct ToolbarIconButton: UIViewRepresentable {
    let systemImage: String
    var tint: UIColor = .label
    var pointSize: CGFloat = 17
    var isEnabled: Bool = true
    let action: () -> Void

    func makeUIView(context: Context) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: systemImage)
        configuration.title = nil
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

        let button = UIButton(configuration: configuration, primaryAction: UIAction { [coordinator = context.coordinator] _ in
            coordinator.action()
        })
        button.tintColor = tint
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        context.coordinator.action = action
        uiView.isEnabled = isEnabled
        uiView.tintColor = tint
        if var configuration = uiView.configuration {
            configuration.image = UIImage(systemName: systemImage)
            uiView.configuration = configuration
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
    }
}

/// Icon-only toolbar menu backed by a real `UIButton` with a native `UIMenu` — title is always
/// nil, tapping shows the menu directly (`showsMenuAsPrimaryAction`) rather than needing a
/// separate press-and-hold, matching how SwiftUI's `Menu` behaves but through UIKit.
struct ToolbarIconMenu: UIViewRepresentable {
    let systemImage: String
    var tint: UIColor = .label
    var pointSize: CGFloat = 17
    let items: [ToolbarMenuItem]

    func makeUIView(context: Context) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: systemImage)
        configuration.title = nil
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

        let button = UIButton(configuration: configuration)
        button.tintColor = tint
        button.showsMenuAsPrimaryAction = true
        button.menu = Self.menu(for: items)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        uiView.tintColor = tint
        uiView.menu = Self.menu(for: items)
        if var configuration = uiView.configuration {
            configuration.image = UIImage(systemName: systemImage)
            uiView.configuration = configuration
        }
    }

    private static func menu(for items: [ToolbarMenuItem]) -> UIMenu {
        UIMenu(children: items.map { item in
            UIAction(title: item.title, image: UIImage(systemName: item.systemImage), attributes: item.isDestructive ? .destructive : []) { _ in
                item.action()
            }
        })
    }
}

struct ToolbarMenuItem {
    let title: String
    let systemImage: String
    var isDestructive: Bool = false
    let action: () -> Void
}
#endif
