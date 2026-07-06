import Foundation

enum MapDisplayLayer: String, Codable, Equatable, CaseIterable, Identifiable {
    case hex
    case province
    case initialTheater
    case dynamicTheater
    case frontLine
    case deployment

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .hex:
            return "地块"
        case .province:
            return "州郡"
        case .initialTheater:
            return "初始方面"
        case .dynamicTheater:
            return "当前方面"
        case .frontLine:
            return "前线"
        case .deployment:
            return "部署"
        }
    }
}
