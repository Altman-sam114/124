import Foundation

enum GamePhase: String, Codable, Equatable, CaseIterable {
    case germanAI
    case alliedPlayer
    case playerCommand
    case aiCommand
    case resolution

    var displayName: String {
        switch self {
        case .germanAI:
            return "朝堂行动"
        case .alliedPlayer:
            return "玩家行动"
        case .playerCommand:
            return "玩家军令"
        case .aiCommand:
            return "朝堂军令"
        case .resolution:
            return "结算"
        }
    }

    var allowsPlayerInput: Bool {
        switch self {
        case .alliedPlayer, .playerCommand:
            return true
        case .germanAI, .aiCommand, .resolution:
            return false
        }
    }

    var allowsAIExecution: Bool {
        switch self {
        case .germanAI, .aiCommand:
            return true
        case .alliedPlayer, .playerCommand, .resolution:
            return false
        }
    }

    func normalized(forActiveFaction activeFaction: Faction, playerFaction: Faction) -> GamePhase {
        let genericPhase: GamePhase = activeFaction == playerFaction ? .playerCommand : .aiCommand
        switch self {
        case .germanAI:
            return activeFaction == .germany && activeFaction != playerFaction ? .germanAI : genericPhase
        case .alliedPlayer:
            return activeFaction == .allies && activeFaction == playerFaction ? .alliedPlayer : genericPhase
        case .playerCommand, .aiCommand:
            return genericPhase
        case .resolution:
            return .resolution
        }
    }

    func allowsCommandExecution(forActiveFaction activeFaction: Faction, playerFaction: Faction) -> Bool {
        normalized(forActiveFaction: activeFaction, playerFaction: playerFaction) != .resolution
    }

}
