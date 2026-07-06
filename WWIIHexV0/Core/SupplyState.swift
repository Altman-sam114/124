import Foundation

enum SupplyState: String, Codable, Equatable, CaseIterable {
    case supplied
    case lowSupply
    case encircled

    var displayName: String {
        switch self {
        case .supplied:
            return "粮道畅通"
        case .lowSupply:
            return "粮草不足"
        case .encircled:
            return "断粮被围"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .supplied:
            return "畅"
        case .lowSupply:
            return "缺粮"
        case .encircled:
            return "被围"
        }
    }
}
