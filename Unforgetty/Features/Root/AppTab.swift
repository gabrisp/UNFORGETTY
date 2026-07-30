import Foundation

enum AppTab: String, CaseIterable {
    case create = "Crear"
    case created = "Creadas"

    var systemImage: String {
        switch self {
        case .create: "pencil"
        case .created: "rectangle.stack.fill"
        }
    }
}
