import Foundation

enum CommandValidationError: String, Codable, Equatable {
    case wrongPhase
    case wrongFaction
    case divisionNotFound
    case targetNotFound
    case alreadyActed
    case destinationOutOfBounds
    case destinationOccupied
    case noPath
    case insufficientMovement
    case targetOutOfRange
    case invalidTargetFaction
    case regionNotFound
    case invalidRegionForHex
    case insufficientResources
    case governanceLimitReached
    case invalidDiplomaticTarget
    case submissionNotAccepted
    case noSubmissionPresence
    case waterCrossingBlocked

    var displayName: String {
        switch self {
        case .wrongPhase:
            return "当前阶段不能执行"
        case .wrongFaction:
            return "行动势力不匹配"
        case .divisionNotFound:
            return "找不到军队"
        case .targetNotFound:
            return "找不到目标"
        case .alreadyActed:
            return "军队已行动"
        case .destinationOutOfBounds:
            return "目标地块超出地图"
        case .destinationOccupied:
            return "目标地块已被占用"
        case .noPath:
            return "没有可通行路径"
        case .insufficientMovement:
            return "行动力不足"
        case .targetOutOfRange:
            return "目标超出射程"
        case .invalidTargetFaction:
            return "目标势力不合法"
        case .regionNotFound:
            return "找不到州郡"
        case .invalidRegionForHex:
            return "地块不属于目标州郡"
        case .insufficientResources:
            return "府库资源不足"
        case .governanceLimitReached:
            return "本回合治理次数已满"
        case .invalidDiplomaticTarget:
            return "外交目标不合法"
        case .submissionNotAccepted:
            return "尚未形成可交接归附关系"
        case .noSubmissionPresence:
            return "归附目标没有可交接实体"
        case .waterCrossingBlocked:
            return "缺少己控水路通行点"
        }
    }
}

struct CommandValidation: Codable, Equatable {
    var errors: [CommandValidationError]

    var isValid: Bool {
        errors.isEmpty
    }

    static let valid = CommandValidation(errors: [])

    static func invalid(_ error: CommandValidationError) -> CommandValidation {
        CommandValidation(errors: [error])
    }
}
