import Foundation

extension GameAgent {
    static func guderian(from loader: DataLoader, state: GameState) -> GameAgent {
        let faction = defaultCommandFaction(in: state)
        let assignedDivisionIds = state.divisions
            .filter { $0.faction == faction && !$0.isDestroyed }
            .map(\.id)
            .sorted()

        if let definition = try? loader.loadGeneralAgents().first(where: { $0.id == "guderian" }) {
            return migratedFallback(
                from: definition,
                faction: faction,
                assignedDivisionIds: assignedDivisionIds
            )
        }

        return guderianFallback(
            faction: faction,
            assignedDivisionIds: assignedDivisionIds
        )
    }

    init?(definition: GeneralAgentDefinition) {
        guard let faction = Faction(rawValue: definition.faction),
              let role = AgentRole(rawValue: definition.role) else {
            return nil
        }
        let resolvedCommandStyle = Self.localizedCommandStyle(definition.commandStyle)

        self.init(
            id: definition.id,
            name: Self.localizedName(for: definition),
            faction: faction,
            role: role,
            personality: AgentPersonality(
                prompt: Self.localizedPersonalityPrompt(for: definition),
                traits: [resolvedCommandStyle],
                aggression: definition.commandStyle == "breakthrough" ? 80 : 50,
                riskTolerance: definition.commandStyle == "breakthrough" ? 75 : 50,
                autonomy: 70
            ),
            relationship: AgentRelationship(loyalty: 70, trust: 70, satisfaction: 70),
            assignedDivisionIds: definition.assignedDivisionIds
        )
    }

    static func guderianFallback(faction: Faction = .tang, assignedDivisionIds: [String]) -> GameAgent {
        GameAgent(
            id: "march_commander_local",
            name: "\(displayFactionName(faction))行军总管",
            faction: faction,
            role: .armyCommander,
            personality: AgentPersonality(
                prompt: "优先考虑破阵突击、道路机动、集中兵力和快速合围。",
                traits: ["突破"],
                aggression: 80,
                riskTolerance: 75,
                autonomy: 70
            ),
            relationship: AgentRelationship(loyalty: 70, trust: 70, satisfaction: 70),
            assignedDivisionIds: assignedDivisionIds
        )
    }

    private static func migratedFallback(
        from definition: GeneralAgentDefinition,
        faction: Faction,
        assignedDivisionIds: [String]
    ) -> GameAgent {
        let resolvedCommandStyle = localizedCommandStyle(definition.commandStyle)
        let aggression = definition.commandStyle == "breakthrough" ? 80 : 50
        return GameAgent(
            id: "march_commander_local",
            name: "\(displayFactionName(faction))行军总管",
            faction: faction,
            role: .armyCommander,
            personality: AgentPersonality(
                prompt: localizedPersonalityPrompt(for: definition),
                traits: [resolvedCommandStyle],
                aggression: aggression,
                riskTolerance: definition.commandStyle == "breakthrough" ? 75 : 50,
                autonomy: 70
            ),
            relationship: AgentRelationship(loyalty: 70, trust: 70, satisfaction: 70),
            assignedDivisionIds: assignedDivisionIds
        )
    }

    private static func localizedName(for definition: GeneralAgentDefinition) -> String {
        switch definition.id {
        case "guderian":
            return "本地行军总管"
        default:
            return definition.name
        }
    }

    private static func localizedPersonalityPrompt(for definition: GeneralAgentDefinition) -> String {
        switch definition.id {
        case "guderian":
            return "优先考虑破阵突击、道路机动、集中兵力和快速合围；没有远程支援时，避免让突击部队消耗在坚固据点正面强攻。"
        default:
            return definition.personalityPrompt
        }
    }

    private static func localizedCommandStyle(_ commandStyle: String) -> String {
        switch commandStyle {
        case "breakthrough":
            return "突破"
        default:
            return commandStyle
        }
    }

    private static func defaultCommandFaction(in state: GameState) -> Faction {
        let available = Set(state.divisions.filter { !$0.isDestroyed }.map(\.faction))
        if !state.scenarioId.hasPrefix("wude_618"), available.contains(.germany) {
            return .germany
        }
        if available.contains(state.playerFaction) {
            return state.playerFaction
        }
        if let suitang = Faction.suitangTurnOrder.first(where: { available.contains($0) }) {
            return suitang
        }
        if available.contains(.germany) {
            return .germany
        }
        if available.contains(.allies) {
            return .allies
        }
        return state.playerFaction
    }

    private static func displayFactionName(_ faction: Faction) -> String {
        switch faction {
        case .germany, .allies:
            return "旧剧本势力"
        default:
            return faction.displayName
        }
    }
}
