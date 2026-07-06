import Foundation

struct CommandExecutor {
    private let movementRules = MovementRules()
    private let combatRules = CombatRules()
    private let supplyRules = SupplyRules()
    private let occupationRules = OccupationRules()
    private let strategicSynchronizer = StrategicStateSynchronizer()
    private let retreatLossThreshold = 0.35

    func execute(_ command: Command, in state: GameState) -> GameState {
        var nextState = state

        switch command {
        case .move(let divisionId, let destination):
            executeMove(divisionId: divisionId, destination: destination, in: &nextState)
        case .attack(let attackerId, let targetId):
            executeAttack(attackerId: attackerId, targetId: targetId, in: &nextState)
        case .hold(let divisionId):
            executeHold(divisionId: divisionId, in: &nextState)
        case .allowRetreat(let divisionId):
            executeAllowRetreat(divisionId: divisionId, in: &nextState)
        case .resupply(let divisionId):
            executeResupply(divisionId: divisionId, in: &nextState)
        case .queueProduction(let kind):
            executeQueueProduction(kind: kind, in: &nextState)
        case .governRegion(let regionId, let policy):
            executeRegionGovernance(regionId: regionId, policy: policy, in: &nextState)
        case .updateDiplomacy(let issuer, let target, let status):
            executeDiplomacyUpdate(issuer: issuer, target: target, status: status, in: &nextState)
        case .resolveSubmissionHandoff(let submitted, let recipient):
            executeSubmissionHandoff(submitted: submitted, recipient: recipient, in: &nextState)
        case .endTurn:
            executeEndTurn(in: &nextState)
        }

        return nextState
    }

    private func executeMove(divisionId: String, destination: HexCoord, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        let origin = state.divisions[index].coord
        let sourceZoneId = state.warDeploymentState.zoneId(for: origin, map: state.map)
        if let direction = directionForMove(from: origin, to: destination, division: state.divisions[index], in: state) {
            state.divisions[index].facing = direction
        }
        state.divisions[index].coord = destination
        state.divisions[index].hasActed = true

        if occupationRules.canOccupy(division: state.divisions[index], destination: destination, in: state),
           var tile = state.map.tile(at: destination) {
            tile.controller = state.divisions[index].faction
            state.map.setTile(tile)
            if let destinationRegionId = state.map.region(for: destination),
               let sourceZoneId {
                applyStrategicAdvance(
                    regionId: destinationRegionId,
                    hex: destination,
                    sourceZoneId: sourceZoneId,
                    faction: state.divisions[index].faction,
                    state: &state
                )
            }
            _ = strategicSynchronizer.synchronizeAfterOccupationChange(
                in: &state,
                affectedRegionIds: state.map.region(for: destination).map { [$0] } ?? []
            )
        }

        state.appendEvent("\(state.divisions[index].name) 已行军至目标地块。")
    }

    private func executeAttack(attackerId: String, targetId: String, in state: inout GameState) {
        guard let attackerIndex = state.divisionIndex(id: attackerId),
              let targetIndex = state.divisionIndex(id: targetId) else {
            return
        }

        let attacker = state.divisions[attackerIndex]
        let defender = state.divisions[targetIndex]
        let damage = combatRules.attackDamage(attacker: attacker, defender: defender, in: state)
        let attackerFacing = attacker.coord.direction(to: defender.coord) ?? attacker.facing

        state.divisions[attackerIndex].hasActed = true
        state.divisions[attackerIndex].facing = attackerFacing
        applyCombatDamage(damage, to: targetId, in: &state)

        let attackOutcome = resolveCombatResult(for: defender, damage: damage, in: &state)
        state.appendEvent(
            combatLog(
                prefix: "\(attacker.name) 进攻 \(defender.name)",
                subjectName: defender.name,
                damage: damage,
                outcome: attackOutcome
            )
        )

        if attackOutcome.wasDestroyed {
            return
        }

        if attackOutcome.shouldRetreat {
            supplyRules.resolveRetreat(for: targetId, in: &state)
        }

        guard let updatedDefender = state.division(id: targetId),
              let updatedAttacker = state.division(id: attackerId) else {
            return
        }

        if !attackOutcome.shouldRetreat,
           combatRules.canCounterAttack(defender: updatedDefender, attacker: updatedAttacker) {
            let counterDamage = combatRules.counterAttackDamage(defender: updatedDefender, attacker: updatedAttacker, in: state)
            applyCombatDamage(counterDamage, to: attackerId, in: &state)

            let counterOutcome = resolveCombatResult(for: updatedAttacker, damage: counterDamage, in: &state)
            state.appendEvent(
                combatLog(
                    prefix: "\(updatedDefender.name) 反击 \(updatedAttacker.name)",
                    subjectName: updatedAttacker.name,
                    damage: counterDamage,
                    outcome: counterOutcome
                )
            )

            if counterOutcome.shouldRetreat && !counterOutcome.wasDestroyed {
                supplyRules.resolveRetreat(for: attackerId, in: &state)
            }
        }
    }

    private func executeHold(divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        state.divisions[index].retreatMode = .hold
        state.divisions[index].hasActed = true
        state.appendEvent("\(state.divisions[index].name) 转入固守：不主动撤退，防御提高，损失承受增加。")
    }

    private func executeAllowRetreat(divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        state.divisions[index].retreatMode = .retreatable
        state.divisions[index].hasActed = true
        state.appendEvent("\(state.divisions[index].name) 改为准退：受重创后可自动撤退。")
    }

    private func executeResupply(divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        supplyRules.applyResupplyRest(to: divisionId, in: &state)
        state.divisions[index].hasActed = true
    }

    private func executeQueueProduction(kind: ProductionKind, in state: inout GameState) {
        _ = EconomyRules().queueProduction(kind: kind, faction: state.activeFaction, in: &state)
    }

    private func executeRegionGovernance(
        regionId: RegionId,
        policy: RegionGovernancePolicy,
        in state: inout GameState
    ) {
        guard var region = state.map.regions[regionId] else {
            return
        }

        var ledger = state.economyState.ledger(for: state.activeFaction)
        ledger.stockpile.subtract(policy.cost)
        ledger.lastUpdatedTurn = state.turn

        let effect: String
        switch policy {
        case .repairRoads:
            let previous = region.infrastructure
            region.infrastructure = min(6, previous + 1)
            effect = "道路仓储 \(previous)->\(region.infrastructure)"
        case .organizeTuntian:
            let previous = region.supplyValue
            region.supplyValue = min(6, previous + 1)
            effect = "粮仓 \(previous)->\(region.supplyValue)"
        case .pacifyPopulation:
            let previous = region.occupationState ?? OccupationState(resistance: 8, compliance: 52)
            let updated = OccupationState(
                resistance: max(0, previous.resistance - 8),
                compliance: min(100, previous.compliance + 12)
            )
            region.occupationState = updated
            effect = "治安 \(previous.resistance)->\(updated.resistance)，顺从 \(previous.compliance)->\(updated.compliance)"
        }

        state.map.regions[regionId] = region
        state.economyState.updateLedger(ledger)
        state.appendEvent(
            "\(state.activeFaction.displayName) 太守令：\(region.name) \(policy.displayName)，耗费 \(policy.cost.displaySummary)，\(effect)。",
            category: .supply
        )
        appendSubmissionAftermathGovernanceRecordIfNeeded(
            region: region,
            policy: policy,
            in: &state
        )
    }

    private func appendSubmissionAftermathGovernanceRecordIfNeeded(
        region: RegionNode,
        policy: RegionGovernancePolicy,
        in state: inout GameState
    ) {
        guard let aftermathRecord = state.diplomacyState.latestSubmissionAftermathRecord,
              aftermathRecord.recipient == state.activeFaction,
              aftermathRecord.affectedRegionIds.contains(region.id) else {
            return
        }

        let record = state.diplomacyState.appendSubmissionAftermathGovernanceRecord(
            faction: state.activeFaction,
            regionId: region.id,
            regionName: region.name,
            policy: policy,
            linkedAftermathRecordId: aftermathRecord.id,
            turn: state.turn
        )
        state.appendEvent(
            "\(record.summary)。",
            category: .diplomacy,
            relatedRecordId: record.id
        )
    }

    private func executeDiplomacyUpdate(
        issuer: Faction,
        target: Faction,
        status: DiplomaticStatus,
        in state: inout GameState
    ) {
        state.diplomacyState.updateRelation(
            issuer: issuer,
            target: target,
            status: status,
            turn: state.turn
        )
        let record = state.diplomacyState.appendDiplomacyEventRecord(
            issuer: issuer,
            target: target,
            status: status,
            turn: state.turn
        )
        state.appendEvent(
            diplomacyLog(issuer: issuer, target: target, status: status),
            category: .diplomacy,
            relatedRecordId: record?.id
        )
    }

    private func executeSubmissionHandoff(
        submitted: Faction,
        recipient: Faction,
        in state: inout GameState
    ) {
        var transferredDivisionCount = 0
        for index in state.divisions.indices
            where state.divisions[index].faction == submitted && !state.divisions[index].isDestroyed {
            state.divisions[index].faction = recipient
            state.divisions[index].hasActed = true
            transferredDivisionCount += 1
        }

        var affectedRegionIds: Set<RegionId> = []
        var transferredHexCount = 0
        for coord in state.map.tiles.keys.sorted(by: { lhs, rhs in
            lhs.q == rhs.q ? lhs.r < rhs.r : lhs.q < rhs.q
        }) {
            guard var tile = state.map.tile(at: coord),
                  tile.controller == submitted,
                  tile.isPassable else {
                continue
            }

            tile.controller = recipient
            state.map.setTile(tile)
            transferredHexCount += 1
            if let regionId = state.map.region(for: coord) {
                affectedRegionIds.insert(regionId)
            }
        }

        if !affectedRegionIds.isEmpty {
            _ = strategicSynchronizer.synchronizeAfterOccupationChange(
                in: &state,
                affectedRegionIds: Array(affectedRegionIds),
                emitRegionOwnerEvents: false
            )
        }
        state = StrategicStateBootstrapper().refreshRuntimeState(state)
        let record = state.diplomacyState.appendSubmissionHandoffRecord(
            submitted: submitted,
            recipient: recipient,
            transferredDivisionCount: transferredDivisionCount,
            transferredHexCount: transferredHexCount,
            affectedRegionIds: Array(affectedRegionIds),
            turn: state.turn
        )
        let aftermathRecord = state.diplomacyState.appendSubmissionAftermathRecord(
            submitted: submitted,
            recipient: recipient,
            transferredDivisionCount: transferredDivisionCount,
            transferredHexCount: transferredHexCount,
            affectedRegionIds: Array(affectedRegionIds),
            linkedHandoffRecordId: record.id,
            turn: state.turn
        )
        state.appendEvent(
            "\(recipient.displayName) 接管 \(submitted.displayName) 归附实体：军队 \(transferredDivisionCount)，地块 \(transferredHexCount)。",
            category: .diplomacy,
            relatedRecordId: record.id
        )
        state.appendEvent(
            "\(aftermathRecord.summary)。",
            category: .diplomacy,
            relatedRecordId: aftermathRecord.id
        )
    }

    private func executeEndTurn(in state: inout GameState) {
        let supplyRules = SupplyRules()
        let victoryRules = VictoryRules()
        let economyRules = EconomyRules()

        supplyRules.updateSupplyStates(in: &state)
        economyRules.resolveFactionTurn(for: state.activeFaction, in: &state)
        supplyRules.advanceRetreats(in: &state)
        supplyRules.applyEncirclementAttrition(in: &state)
        victoryRules.updateVictoryState(in: &state)

        advanceActiveFaction(in: &state)

        resetActionsForActiveFaction(in: &state)
        state = StrategicStateBootstrapper().refreshRuntimeState(state)
        state.appendEvent("进入第 \(state.turn) 回合，\(state.activeFaction.displayName) 行动。")
    }

    private func advanceActiveFaction(in state: inout GameState) {
        switch state.phase {
        case .germanAI:
            state.activeFaction = .allies
            state.phase = .alliedPlayer
            return
        case .alliedPlayer:
            state.activeFaction = .germany
            state.phase = .germanAI
            state.turn += 1
            return
        case .playerCommand, .aiCommand, .resolution:
            break
        }

        let order = turnOrder(in: state)
        guard let currentIndex = order.firstIndex(of: state.activeFaction) else {
            state.activeFaction = order.first ?? .tang
            state.phase = phase(for: state.activeFaction, in: state)
            return
        }

        let nextIndex = (currentIndex + 1) % order.count
        state.activeFaction = order[nextIndex]
        state.phase = phase(for: state.activeFaction, in: state)
        if nextIndex == 0 {
            state.turn += 1
        }
    }

    private func turnOrder(in state: GameState) -> [Faction] {
        var factions = Set(state.diplomacyState.countries.map(\.faction))
        factions.formUnion(state.divisions.map(\.faction))
        factions.formUnion(state.map.tiles.values.compactMap(\.controller))
        factions = Set(factions.filter { shouldIncludeInTurnOrder($0, in: state) })

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

    private func shouldIncludeInTurnOrder(_ faction: Faction, in state: GameState) -> Bool {
        guard isSubmittedWithoutRuntimePresence(faction, in: state) else {
            return true
        }
        return false
    }

    private func isSubmittedWithoutRuntimePresence(_ faction: Faction, in state: GameState) -> Bool {
        isSubmittedFaction(faction, in: state.diplomacyState) &&
            !hasActiveDivision(faction, in: state) &&
            !controlsPassableHex(faction, in: state)
    }

    private func isSubmittedFaction(_ faction: Faction, in diplomacyState: DiplomacyState) -> Bool {
        diplomacyState.isSubmittedTarget(faction)
    }

    private func hasActiveDivision(_ faction: Faction, in state: GameState) -> Bool {
        state.divisions.contains { $0.faction == faction && !$0.isDestroyed }
    }

    private func controlsPassableHex(_ faction: Faction, in state: GameState) -> Bool {
        state.map.tiles.values.contains { tile in
            tile.controller == faction && tile.isPassable
        }
    }

    private func phase(for faction: Faction, in state: GameState) -> GamePhase {
        faction == state.playerFaction ? .playerCommand : .aiCommand
    }

    private func resetActionsForActiveFaction(in state: inout GameState) {
        for index in state.divisions.indices where state.divisions[index].faction == state.activeFaction {
            state.divisions[index].hasActed = false
        }
    }

    private func directionForMove(
        from origin: HexCoord,
        to destination: HexCoord,
        division: Division,
        in state: GameState
    ) -> HexDirection? {
        if let path = movementRules.shortestPath(for: division, to: destination, in: state),
           path.coords.count >= 2 {
            let previous = path.coords[path.coords.count - 2]
            return previous.direction(to: destination)
        }

        return origin.direction(to: destination)
    }

    private func applyCombatDamage(_ damage: CombatDamage, to divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        state.divisions[index].receiveStrengthDamage(damage.strengthDamage)
    }

    private func resolveCombatResult(
        for originalDivision: Division,
        damage: CombatDamage,
        in state: inout GameState
    ) -> CombatResultSummary {
        guard let index = state.divisionIndex(id: originalDivision.id) else {
            return CombatResultSummary(shouldRetreat: false, wasDestroyed: true, extraStrengthDamage: 0)
        }

        let shouldRetreat = state.divisions[index].retreatMode == .retreatable &&
            !state.divisions[index].isDestroyed &&
            damage.lossRatio >= retreatLossThreshold
        var extraStrengthDamage = 0

        if state.divisions[index].retreatMode == .hold && !state.divisions[index].isDestroyed {
            extraStrengthDamage += max(1, Int((Double(damage.strengthDamage) * 0.2).rounded()))
            state.divisions[index].receiveStrengthDamage(extraStrengthDamage)
        }

        if shouldRetreat && state.divisions[index].supplyState == .encircled && !state.divisions[index].isDestroyed {
            extraStrengthDamage = max(1, damage.strengthDamage / 2)
            state.divisions[index].receiveStrengthDamage(extraStrengthDamage)
        }

        if state.divisions[index].isDestroyed {
            eliminateDivision(originalDivision, in: &state)
            return CombatResultSummary(
                shouldRetreat: shouldRetreat,
                wasDestroyed: true,
                extraStrengthDamage: extraStrengthDamage
            )
        }

        if shouldRetreat {
            state.divisions[index].hasActed = true
        }

        return CombatResultSummary(
            shouldRetreat: shouldRetreat,
            wasDestroyed: false,
            extraStrengthDamage: extraStrengthDamage
        )
    }

    private func eliminateDivision(_ division: Division, in state: inout GameState) {
        state.victoryState.recordEliminatedDivision(faction: division.faction)
        state.removeDivision(id: division.id)
    }

    private func applyStrategicAdvance(
        regionId: RegionId,
        hex: HexCoord,
        sourceZoneId: FrontZoneId,
        faction: Faction,
        state: inout GameState
    ) {
        let advancingTheaterId = TheaterId(sourceZoneId.rawValue)
        guard state.theaterState.theaters[advancingTheaterId] != nil,
              state.theaterState.dynamicTheaterId(for: hex, map: state.map) != advancingTheaterId else {
            return
        }
        guard shouldAdvanceDynamicTheater(
            hex: hex,
            sourceZoneId: sourceZoneId,
            faction: faction,
            state: state
        ) else {
            return
        }

        state.theaterState = TheaterSystem().expandDynamicTheater(
            state: state.theaterState,
            map: state.map,
            divisions: state.divisions,
            breakthroughHex: hex,
            advancingTheaterId: advancingTheaterId,
            faction: faction
        ).state

        let oldZoneId = state.warDeploymentState.zoneId(for: hex, map: state.map)
        if oldZoneId != sourceZoneId {
            state.warDeploymentState = WarDeploymentManager().advanceHex(
                hex,
                from: oldZoneId,
                to: sourceZoneId,
                state: state.warDeploymentState,
                map: state.map,
                divisions: state.divisions,
                turn: state.turn
            )
        }

        let theaterName = displayTheaterName(state.theaterState.theaters[advancingTheaterId]?.name)
        let regionName = state.map.region(id: regionId)?.name ?? "相关州郡"
        state.appendEvent(
            "\(regionName) 前沿地块已纳入 \(theaterName) 推进范围。",
            category: .theaterChange,
            relatedRecordId: nil
        )
    }

    private func displayTheaterName(_ name: String?) -> String {
        guard let name,
              !name.isEmpty,
              !name.contains("_"),
              !name.hasPrefix("theater") else {
            return "当前方面"
        }
        return name
    }

    private func shouldAdvanceDynamicTheater(
        hex: HexCoord,
        sourceZoneId: FrontZoneId,
        faction: Faction,
        state: GameState
    ) -> Bool {
        let destinationZoneId = state.warDeploymentState.zoneId(for: hex, map: state.map)
        if let destinationZoneId,
           destinationZoneId != sourceZoneId,
           let destinationFaction = state.warDeploymentState.frontZones[destinationZoneId]?.faction {
            return destinationFaction != faction
        }

        if let controller = state.map.tile(at: hex)?.controller {
            return controller != faction
        }

        return false
    }

    private func combatLog(
        prefix: String,
        subjectName: String,
        damage: CombatDamage,
        outcome: CombatResultSummary
    ) -> String {
        var parts = [
            "\(prefix)：兵力 -\(damage.strengthDamage)"
        ]

        if outcome.shouldRetreat {
            parts.append("\(subjectName) 触发自动撤退")
        }

        if outcome.extraStrengthDamage > 0 {
            parts.append("额外兵力 -\(outcome.extraStrengthDamage)")
        }

        if outcome.wasDestroyed {
            parts.append("\(subjectName) 已被击溃")
        }

        return parts.joined(separator: "；") + "。"
    }

    private func diplomacyLog(issuer: Faction, target: Faction, status: DiplomaticStatus) -> String {
        switch status {
        case .allied:
            return "\(issuer.displayName) 与 \(target.displayName) 缔结盟约。"
        case .coBelligerent:
            return "\(issuer.displayName) 与 \(target.displayName) 协同讨伐。"
        case .neutral:
            return "\(issuer.displayName) 与 \(target.displayName) 恢复中立。"
        case .truce:
            return "\(issuer.displayName) 与 \(target.displayName) 议定停战。"
        case .vassal:
            return "\(target.displayName) 向 \(issuer.displayName) 称臣。"
        case .submitted:
            return "\(target.displayName) 归附 \(issuer.displayName)。"
        case .hostile:
            return "\(issuer.displayName) 与 \(target.displayName) 转为敌对。"
        case .atWar:
            return "\(issuer.displayName) 对 \(target.displayName) 宣战。"
        }
    }
}

private struct CombatResultSummary: Equatable {
    let shouldRetreat: Bool
    let wasDestroyed: Bool
    let extraStrengthDamage: Int
}
