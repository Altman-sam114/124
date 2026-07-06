import Foundation

enum Command: Codable, Equatable {
    case move(divisionId: String, destination: HexCoord)
    case attack(attackerId: String, targetId: String)
    case hold(divisionId: String)
    case allowRetreat(divisionId: String)
    case resupply(divisionId: String)
    case queueProduction(kind: ProductionKind)
    case governRegion(regionId: RegionId, policy: RegionGovernancePolicy)
    case updateDiplomacy(issuer: Faction, target: Faction, status: DiplomaticStatus)
    case resolveSubmissionHandoff(submitted: Faction, recipient: Faction)
    case endTurn

    static func rest(divisionId: String) -> Command {
        .resupply(divisionId: divisionId)
    }

    static func reinforce(divisionId: String) -> Command {
        .resupply(divisionId: divisionId)
    }

    var displayName: String {
        switch self {
        case .move:
            return "行军至目标地块"
        case .attack:
            return "进攻"
        case .hold:
            return "坚守"
        case .allowRetreat:
            return "准许撤退"
        case .resupply:
            return "补给休整"
        case .queueProduction(let kind):
            return "征发 \(kind.displayName)"
        case .governRegion(_, let policy):
            return "州郡经营：\(policy.displayName)"
        case .updateDiplomacy(let issuer, let target, let status):
            return "外交：\(issuer.displayName) 与 \(target.displayName) \(status.displayName)"
        case .resolveSubmissionHandoff(let submitted, let recipient):
            return "归附交接：\(submitted.displayName) 至 \(recipient.displayName)"
        case .endTurn:
            return "结束回合"
        }
    }

    var actingDivisionId: String? {
        switch self {
        case .move(let divisionId, _),
             .hold(let divisionId),
             .allowRetreat(let divisionId),
             .resupply(let divisionId):
            return divisionId
        case .attack(let attackerId, _):
            return attackerId
        case .queueProduction:
            return nil
        case .governRegion:
            return nil
        case .updateDiplomacy:
            return nil
        case .resolveSubmissionHandoff:
            return nil
        case .endTurn:
            return nil
        }
    }

    var isRecoveryCommand: Bool {
        switch self {
        case .resupply:
            return true
        case .move,
             .attack,
             .hold,
             .allowRetreat,
             .queueProduction,
             .governRegion,
             .updateDiplomacy,
             .resolveSubmissionHandoff,
             .endTurn:
            return false
        }
    }
}

enum RegionGovernancePolicy: String, Codable, Equatable, CaseIterable, Identifiable {
    case repairRoads
    case organizeTuntian
    case pacifyPopulation

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .repairRoads:
            return "修道"
        case .organizeTuntian:
            return "屯田"
        case .pacifyPopulation:
            return "安民"
        }
    }

    var cost: EconomyResources {
        switch self {
        case .repairRoads:
            return EconomyResources(industry: 28, supplies: 12)
        case .organizeTuntian:
            return EconomyResources(manpower: 12, industry: 22, supplies: 28)
        case .pacifyPopulation:
            return EconomyResources(manpower: 8, supplies: 18)
        }
    }

    func canApply(to region: RegionNode) -> Bool {
        switch self {
        case .repairRoads:
            return region.infrastructure < 6
        case .organizeTuntian:
            return region.supplyValue < 6
        case .pacifyPopulation:
            guard let occupation = region.occupationState else {
                return true
            }
            return occupation.resistance > 0 || occupation.compliance < 80
        }
    }

    func effectSummary(for region: RegionNode) -> String {
        switch self {
        case .repairRoads:
            return "道路仓储 +1，最高 6"
        case .organizeTuntian:
            return "粮仓 +1，最高 6"
        case .pacifyPopulation:
            let occupation = region.occupationState ?? OccupationState(resistance: 8, compliance: 52)
            let resistance = max(0, occupation.resistance - 8)
            let compliance = min(100, occupation.compliance + 12)
            return "治安 \(occupation.resistance)->\(resistance)，顺从 \(occupation.compliance)->\(compliance)"
        }
    }
}
