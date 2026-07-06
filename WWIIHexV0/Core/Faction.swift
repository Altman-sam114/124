import Foundation

enum Faction: String, Codable, Equatable, CaseIterable {
    case germany
    case allies
    case tang
    case luoyangSui
    case wagang
    case xia
    case qinXue
    case liuWuzhou
    case tujue

    static var legacyCombatants: [Faction] {
        [.germany, .allies]
    }

    static var suitangTurnOrder: [Faction] {
        [.tang, .luoyangSui, .wagang, .xia, .qinXue, .liuWuzhou, .tujue]
    }

    var opponent: Faction {
        switch self {
        case .germany:
            return .allies
        case .allies:
            return .germany
        case .tang:
            return .luoyangSui
        case .luoyangSui,
             .wagang,
             .xia,
             .qinXue,
             .liuWuzhou,
             .tujue:
            return .tang
        }
    }

    var displayName: String {
        switch self {
        case .germany:
            return "旧剧本东路势力"
        case .allies:
            return "旧剧本西路势力"
        case .tang:
            return "唐"
        case .luoyangSui:
            return "洛阳隋"
        case .wagang:
            return "瓦岗"
        case .xia:
            return "夏"
        case .qinXue:
            return "秦"
        case .liuWuzhou:
            return "刘武周"
        case .tujue:
            return "东突厥"
        }
    }

    var usesDefaultHumanControl: Bool {
        self == .allies || self == .tang
    }
}
