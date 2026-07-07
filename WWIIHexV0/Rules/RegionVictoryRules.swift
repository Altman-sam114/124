import Foundation

typealias RegionVictoryAssessment = VictoryAssessment

struct RegionVictoryRules {
    func assessVictory(in state: GameState) -> RegionVictoryAssessment {
        let semantics = ScenarioSemantics(scenarioId: state.scenarioId)
        if semantics.family == .wude618 {
            return Wude618VictoryEvaluator.assess(in: state)
        }

        if semantics.isLegacy {
            return assessLegacyFallbackVictory(in: state)
        }

        return .ongoing
    }

    private func assessLegacyFallbackVictory(in state: GameState) -> RegionVictoryAssessment {
        let primaryObjectiveController = controller(
            ofObjectiveId: LegacyFallbackRegionObjective.primaryId,
            cityNames: [LegacyFallbackRegionObjective.primaryDisplayName],
            in: state
        )
        let secondaryObjectiveController = controller(
            ofObjectiveId: LegacyFallbackRegionObjective.secondaryId,
            cityNames: [LegacyFallbackRegionObjective.secondaryDisplayName],
            in: state
        )

        if primaryObjectiveController == .germany && secondaryObjectiveController == .germany {
            return RegionVictoryAssessment(winner: .germany, reason: .bastogneAndStVithControlledByGermany)
        }

        if state.turn >= state.maxTurns && primaryObjectiveController == .allies {
            return RegionVictoryAssessment(winner: .allies, reason: .bastogneHeldByAlliesAtFinalTurn)
        }

        return RegionVictoryAssessment(winner: nil, reason: nil)
    }

    func controller(ofCityNamed name: String, in state: GameState) -> Faction? {
        state.map.regions.values.first { $0.city?.name == name }?.controller
    }

    private func controller(ofObjectiveId objectiveId: String, cityNames: [String], in state: GameState) -> Faction? {
        if let controller = state.map.controllerOfObjective(id: objectiveId) {
            return controller
        }

        for name in cityNames {
            if let controller = controller(ofCityNamed: name, in: state) {
                return controller
            }
        }

        return nil
    }
}

private enum LegacyFallbackRegionObjective {
    static let primaryId = "bastogne"
    static let secondaryId = "st_vith"
    static let primaryDisplayName = "旧战局要地甲"
    static let secondaryDisplayName = "旧战局要地乙"
}
