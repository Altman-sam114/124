import Foundation

enum VictoryReason: String, Codable, Equatable {
    case bastogneHeldByGermany
    case bastogneAndStVithControlledByGermany
    case alliedUnitsDestroyed
    case bastogneHeldByAlliesAtFinalTurn
    case germanUnitsDestroyed
    case germanArmorUnsupplied
    case tangControlsLuoyangAndLuokou
    case luoyangSuiBreaksTongguan
    case tangHoldsChanganAtFinalTurn
    case tangLosesChanganAtFinalTurn

    var displayName: String {
        switch self {
        case .bastogneHeldByGermany:
            return "旧战局目标被东路势力控制"
        case .bastogneAndStVithControlledByGermany:
            return "旧战局双目标被东路势力控制"
        case .alliedUnitsDestroyed:
            return "旧战局西路主力被击溃"
        case .bastogneHeldByAlliesAtFinalTurn:
            return "旧战局西路势力终局守住目标"
        case .germanUnitsDestroyed:
            return "旧战局东路主力被击溃"
        case .germanArmorUnsupplied:
            return "旧战局东路主力断粮"
        case .tangControlsLuoyangAndLuokou:
            return "克洛阳与洛口仓"
        case .luoyangSuiBreaksTongguan:
            return "夺潼关入关中"
        case .tangHoldsChanganAtFinalTurn:
            return "终局守长安"
        case .tangLosesChanganAtFinalTurn:
            return "终局长安失守"
        }
    }
}

struct VictoryAssessment: Equatable {
    let winner: Faction?
    let reason: VictoryReason?

    static let ongoing = VictoryAssessment(winner: nil, reason: nil)
}

struct VictoryState: Codable, Equatable {
    var winner: Faction?
    var reason: VictoryReason?
    var eliminatedGermanDivisions: Int
    var eliminatedAlliedDivisions: Int
    var germanBastogneHeldSinceTurn: Int?
    var germanArmorUnsuppliedSinceTurn: Int?

    static var ongoing: VictoryState {
        VictoryState(
            winner: nil,
            reason: nil,
            eliminatedGermanDivisions: 0,
            eliminatedAlliedDivisions: 0,
            germanBastogneHeldSinceTurn: nil,
            germanArmorUnsuppliedSinceTurn: nil
        )
    }

    mutating func recordEliminatedDivision(faction: Faction) {
        switch faction {
        case .germany:
            eliminatedGermanDivisions += 1
        case .allies:
            eliminatedAlliedDivisions += 1
        default:
            break
        }
    }

    mutating func apply(_ assessment: VictoryAssessment) {
        winner = assessment.winner
        reason = assessment.reason
    }
}
