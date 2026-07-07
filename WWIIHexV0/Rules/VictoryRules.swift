import Foundation

enum Wude618VictoryEvaluator {
    static let scenarioId = "wude_618_guanzhong_luoyang"

    static func assess(in state: GameState) -> VictoryAssessment {
        let luoyangController = state.map.controllerOfObjective(id: "obj_luoyang")
        let luokouController = state.map.controllerOfObjective(id: "obj_luokou")
        let tongguanController = state.map.controllerOfObjective(id: "obj_tongguan")
        let changanController = state.map.controllerOfObjective(id: "obj_changan")

        if luoyangController == .tang && luokouController == .tang {
            return VictoryAssessment(winner: .tang, reason: .tangControlsLuoyangAndLuokou)
        }

        if tongguanController == .luoyangSui {
            return VictoryAssessment(winner: .luoyangSui, reason: .luoyangSuiBreaksTongguan)
        }

        guard isCompletingFinalRound(in: state) else {
            return .ongoing
        }

        if changanController == .tang {
            return VictoryAssessment(winner: .tang, reason: .tangHoldsChanganAtFinalTurn)
        }
        if let changanController {
            return VictoryAssessment(winner: changanController, reason: .tangLosesChanganAtFinalTurn)
        }

        return .ongoing
    }

    private static func isCompletingFinalRound(in state: GameState) -> Bool {
        guard state.turn >= state.maxTurns else {
            return false
        }

        return factionTurnOrder(in: state).last == state.activeFaction
    }

    private static func factionTurnOrder(in state: GameState) -> [Faction] {
        var factions = Set(state.diplomacyState.countries.map(\.faction))
        factions.formUnion(state.divisions.map(\.faction))
        factions.formUnion(state.map.tiles.values.compactMap(\.controller))

        if factions.isEmpty {
            return Faction.legacyCombatants
        }
        if factions.isSubset(of: Set(Faction.legacyCombatants)) {
            return Faction.legacyCombatants.filter { factions.contains($0) }
        }

        let preferred = Faction.suitangTurnOrder.filter { factions.contains($0) }
        let legacy = Faction.legacyCombatants.filter { factions.contains($0) }
        let known = Set(preferred + legacy)
        let remaining = factions
            .subtracting(known)
            .sorted { $0.rawValue < $1.rawValue }
        return preferred + legacy + remaining
    }
}

struct VictoryRules {
    func updateVictoryState(in state: inout GameState) {
        guard state.victoryState.winner == nil else {
            return
        }

        let semantics = ScenarioSemantics(scenarioId: state.scenarioId)
        if semantics.family == .wude618 {
            state.victoryState.apply(Wude618VictoryEvaluator.assess(in: state))
            return
        }

        if semantics.isLegacy {
            updateLegacyFallbackVictoryState(in: &state)
        }
    }

    private func updateLegacyFallbackVictoryState(in state: inout GameState) {
        let primaryObjectiveController = state.map.controllerOfObjective(id: LegacyFallbackObjective.primaryId)
            ?? state.map.controllerOfObjective(named: LegacyFallbackObjective.primaryDisplayName)
        let secondaryObjectiveController = state.map.controllerOfObjective(id: LegacyFallbackObjective.secondaryId)
            ?? state.map.controllerOfObjective(named: LegacyFallbackObjective.secondaryDisplayName)

        if primaryObjectiveController == .germany {
            if let heldSince = state.victoryState.germanBastogneHeldSinceTurn,
               state.turn > heldSince {
                state.victoryState.winner = .germany
                state.victoryState.reason = .bastogneHeldByGermany
                return
            } else if state.victoryState.germanBastogneHeldSinceTurn == nil {
                state.victoryState.germanBastogneHeldSinceTurn = state.turn
            }
        } else {
            state.victoryState.germanBastogneHeldSinceTurn = nil
        }

        if primaryObjectiveController == .germany && secondaryObjectiveController == .germany {
            state.victoryState.winner = .germany
            state.victoryState.reason = .bastogneAndStVithControlledByGermany
            return
        }

        if state.victoryState.eliminatedAlliedDivisions >= 3 {
            state.victoryState.winner = .germany
            state.victoryState.reason = .alliedUnitsDestroyed
            return
        }

        if state.victoryState.eliminatedGermanDivisions >= 3 {
            state.victoryState.winner = .allies
            state.victoryState.reason = .germanUnitsDestroyed
            return
        }

        let legacyMobileForces = state.divisions.filter { $0.faction == .germany && $0.isArmor }
        if !legacyMobileForces.isEmpty && legacyMobileForces.allSatisfy({ $0.supplyState != .supplied }) {
            if let since = state.victoryState.germanArmorUnsuppliedSinceTurn,
               state.turn > since {
                state.victoryState.winner = .allies
                state.victoryState.reason = .germanArmorUnsupplied
                return
            } else if state.victoryState.germanArmorUnsuppliedSinceTurn == nil {
                state.victoryState.germanArmorUnsuppliedSinceTurn = state.turn
            }
        } else {
            state.victoryState.germanArmorUnsuppliedSinceTurn = nil
        }

        if state.turn >= state.maxTurns && primaryObjectiveController == .allies {
            state.victoryState.winner = .allies
            state.victoryState.reason = .bastogneHeldByAlliesAtFinalTurn
        }
    }
}

private enum LegacyFallbackObjective {
    static let primaryId = "bastogne"
    static let secondaryId = "st_vith"
    static let primaryDisplayName = "旧战局要地甲"
    static let secondaryDisplayName = "旧战局要地乙"
}
