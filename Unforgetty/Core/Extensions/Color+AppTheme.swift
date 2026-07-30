import SwiftUI

extension Color {
    static var secondarybg: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color.gray.opacity(0.08)
        #endif
    }
}
