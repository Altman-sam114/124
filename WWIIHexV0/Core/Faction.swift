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

struct ScenarioSemantics: Equatable {
    enum Family: Equatable {
        case legacy
        case wude618
        case suitangDraft
        case custom
    }

    let scenarioId: String
    let family: Family

    init(scenarioId: String) {
        self.scenarioId = scenarioId

        if scenarioId == "ardennes_v0" || scenarioId.hasPrefix("ardennes") {
            self.family = .legacy
        } else if scenarioId == "wude_618_guanzhong_luoyang" {
            self.family = .wude618
        } else if scenarioId.hasPrefix("wude_618") ||
            scenarioId.hasPrefix("suitang") ||
            scenarioId.hasPrefix("sui_tang") {
            self.family = .suitangDraft
        } else {
            self.family = .custom
        }
    }

    var isLegacy: Bool {
        family == .legacy
    }

    var prefersSuitangAssets: Bool {
        switch family {
        case .wude618, .suitangDraft, .custom:
            return true
        case .legacy:
            return false
        }
    }

    var defaultInitialPhase: GamePhase {
        isLegacy ? .alliedPlayer : .playerCommand
    }

    var defaultPlayerFaction: Faction {
        isLegacy ? .allies : .tang
    }

    var defaultAIFaction: Faction {
        isLegacy ? .germany : .luoyangSui
    }

    func resolvedPlayerFaction(rawValue: String, scenarioFactions: [String] = []) -> Faction {
        if let faction = Faction(rawValue: rawValue) {
            return faction
        }
        if let fallback = preferredFaction(in: scenarioFactions.compactMap(Faction.init(rawValue:))) {
            return fallback
        }
        return defaultPlayerFaction
    }

    func resolvedAIFaction(rawValue: String, playerFaction: Faction, scenarioFactions: [String] = []) -> Faction {
        if let faction = Faction(rawValue: rawValue) {
            return faction
        }
        let available = scenarioFactions.compactMap(Faction.init(rawValue:)).filter { $0 != playerFaction }
        if let fallback = preferredFaction(in: available) {
            return fallback
        }
        return defaultAIFaction
    }

    func resolvedActiveFaction(
        phase: GamePhase,
        playerRawValue: String,
        aiRawValue: String,
        scenarioFactions: [String] = []
    ) -> Faction {
        let player = resolvedPlayerFaction(rawValue: playerRawValue, scenarioFactions: scenarioFactions)
        switch phase {
        case .alliedPlayer, .playerCommand, .resolution:
            return player
        case .germanAI, .aiCommand:
            return resolvedAIFaction(
                rawValue: aiRawValue,
                playerFaction: player,
                scenarioFactions: scenarioFactions
            )
        }
    }

    func playerFactionForMissingSave(activeFaction: Faction) -> Faction {
        if activeFaction.usesDefaultHumanControl {
            return activeFaction
        }
        return defaultPlayerFaction
    }

    func preferredCommandFaction(available: Set<Faction>, playerFaction: Faction) -> Faction {
        if available.contains(playerFaction) {
            return playerFaction
        }
        if isLegacy, available.contains(.germany) {
            return .germany
        }
        if let suitang = Faction.suitangTurnOrder.first(where: { available.contains($0) }) {
            return suitang
        }
        if isLegacy, available.contains(.allies) {
            return .allies
        }
        if let remaining = available.sorted(by: { $0.rawValue < $1.rawValue }).first {
            return remaining
        }
        return playerFaction
    }

    private func preferredFaction(in factions: [Faction]) -> Faction? {
        if isLegacy {
            return Faction.legacyCombatants.first { factions.contains($0) } ??
                factions.sorted { $0.rawValue < $1.rawValue }.first
        }
        return Faction.suitangTurnOrder.first { factions.contains($0) } ??
            factions.sorted { $0.rawValue < $1.rawValue }.first
    }
}
