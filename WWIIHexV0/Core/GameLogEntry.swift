import Foundation

enum GameLogCategory: String, Codable, Equatable {
    case combat
    case retreat
    case reinforce
    case encircle
    case supply
    case frontChange
    case theaterChange
    case regionOwnerChange
    case diplomacy
    case event
}

struct GameLogEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let turn: Int
    let faction: Faction?
    let phase: GamePhase?
    let category: GameLogCategory
    let relatedRecordId: String?
    let message: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        turn: Int,
        faction: Faction?,
        phase: GamePhase?,
        category: GameLogCategory = .event,
        relatedRecordId: String? = nil,
        message: String,
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.id = id
        self.turn = turn
        self.faction = faction
        self.phase = phase
        self.category = category
        self.relatedRecordId = relatedRecordId
        self.message = Self.sanitizedMessage(message)
        self.createdAt = createdAt
    }

    private static func sanitizedMessage(_ message: String) -> String {
        sanitizeRawIdentifiers(in: message)
            .replacingOccurrences(of: "德军（旧）", with: "旧剧本势力")
            .replacingOccurrences(of: "盟军（旧）", with: "旧剧本势力")
            .replacingOccurrences(of: "德军", with: "旧剧本势力")
            .replacingOccurrences(of: "盟军", with: "旧剧本势力")
            .replacingOccurrences(of: "旧剧本德方", with: "旧剧本国家")
            .replacingOccurrences(of: "旧剧本美方", with: "旧剧本国家")
            .replacingOccurrences(of: "旧剧本英方", with: "旧剧本国家")
            .replacingOccurrences(of: "Heinz Guderian", with: "历史总管")
            .replacingOccurrences(of: "Guderian", with: "历史总管")
            .replacingOccurrences(of: "Field Marshal", with: "行军总管")
            .replacingOccurrences(of: "Army Commander", with: "行军总管")
            .replacingOccurrences(of: "Germany", with: "旧剧本势力")
            .replacingOccurrences(of: "Allies", with: "旧剧本势力")
            .replacingOccurrences(of: "German", with: "旧剧本势力")
            .replacingOccurrences(of: "rawJSON", with: "军情记录")
            .replacingOccurrences(of: "JSON", with: "军情记录")
            .replacingOccurrences(of: "json", with: "军情记录")
            .replacingOccurrences(of: "schema", with: "格式")
            .replacingOccurrences(of: "provider", with: "来源")
            .replacingOccurrences(of: "反装甲", with: "拒马弩")
            .replacingOccurrences(of: "反甲骑", with: "拒马弩")
            .replacingOccurrences(of: "装甲", with: "甲骑")
            .replacingOccurrences(of: "摩托化", with: "骑军")
            .replacingOccurrences(of: "炮兵", with: "弓弩")
            .replacingOccurrences(of: "步兵", with: "步卒")
            .replacingOccurrences(of: "阿登", with: "旧战局")
            .replacingOccurrences(of: "巴斯托涅", with: "旧战局要地")
            .replacingOccurrences(of: "圣维特", with: "旧战局要地")
            .replacingOccurrences(of: "Ardennes", with: "旧战局")
            .replacingOccurrences(of: "Bastogne", with: "旧战局要地")
            .replacingOccurrences(of: "St. Vith", with: "旧战局要地")
            .replacingOccurrences(of: "St Vith", with: "旧战局要地")
            .replacingOccurrences(of: "Sedan", with: "旧战局要地")
    }

    private static func sanitizeRawIdentifiers(in message: String) -> String {
        message
            .replacingOccurrences(
                of: #"\bwar_directive_[A-Za-z0-9_\-]+\b"#,
                with: "方面军令审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bplayer_directive_[A-Za-z0-9_\-]+\b"#,
                with: "玩家军令审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bplayer_operation_[A-Za-z0-9_\-]+\b"#,
                with: "预备军令审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bsubmission_handoff_[A-Za-z0-9_\-]+\b"#,
                with: "归附交接审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bsubmission_aftermath_[A-Za-z0-9_\-]+\b"#,
                with: "归附善后审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bdiplomacy_event_[A-Za-z0-9_\-]+\b"#,
                with: "外交记录",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bdiplomacy_[0-9]+_[A-Za-z0-9_\-]+\b"#,
                with: "外交记录",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bcourt_decision_[A-Za-z0-9_\-]+\b"#,
                with: "朝堂审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bcourt_[A-Za-z0-9_\-]+_turn_[0-9]+\b"#,
                with: "朝堂审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bcourt_[0-9]+_[A-Za-z0-9_\-]+\b"#,
                with: "朝堂审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bruler_decision_[A-Za-z0-9_\-]+\b"#,
                with: "君主审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bruler_[A-Za-z0-9_\-]+_turn_[A-Za-z0-9_\-]+\b"#,
                with: "君主审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bregion_[A-Za-z0-9_\-]+\b"#,
                with: "相关州郡",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\btheater_[A-Za-z0-9_\-]+\b"#,
                with: "相关方面",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bfront_zone_[A-Za-z0-9_\-]+\b"#,
                with: "相关防区",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(obj|objective)_[A-Za-z0-9_\-]+\b"#,
                with: "相关要地",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bhex_[A-Za-z0-9_\-]+\b"#,
                with: "相关地块",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(division|unit)_[A-Za-z0-9_\-]+\b"#,
                with: "相关军队",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bcommand_[A-Za-z0-9_\-]+\b"#,
                with: "相关军令",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bagent_[A-Za-z0-9_\-]+\b"#,
                with: "朝堂记录",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(marshal|mock|sovereign|strategist|diplomat|governor_staff|march_commander|general_staff)_[A-Za-z0-9_\-]+\b"#,
                with: "朝堂记录",
                options: .regularExpression
            )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case turn
        case faction
        case phase
        case category
        case relatedRecordId
        case message
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            turn: try container.decode(Int.self, forKey: .turn),
            faction: try container.decodeIfPresent(Faction.self, forKey: .faction),
            phase: try container.decodeIfPresent(GamePhase.self, forKey: .phase),
            category: try container.decodeIfPresent(GameLogCategory.self, forKey: .category) ?? .event,
            relatedRecordId: try container.decodeIfPresent(String.self, forKey: .relatedRecordId),
            message: try container.decode(String.self, forKey: .message),
            createdAt: try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
        )
    }
}
