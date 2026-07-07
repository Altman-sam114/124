import Foundation

struct SupplyRules {
    let maxSupplyPathCost = 7
    let suppliedResupplyHPRecovery = 2
    let encircledHPLoss = 1
    let failedRetreatHPLoss = 1
    private let movementRules = MovementRules()

    func updateSupplyStates(in state: inout GameState) {
        let snapshot = state
        for index in state.divisions.indices {
            let division = state.divisions[index]
            let previousState = division.supplyState
            let nextState = supplyState(for: division, in: snapshot)
            state.divisions[index].supplyState = nextState

            if previousState != nextState,
               nextState == .encircled,
               isBesieged(division, in: snapshot) {
                state.appendEvent(
                    "\(division.name) 在\(settlementName(for: division, in: snapshot))断粮被围，城防恢复受限。",
                    category: .supply
                )
            }
        }
    }

    func applyResupplyRest(to divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        state.divisions[index].supplyState = supplyState(for: state.divisions[index], in: state)
        let before = state.divisions[index]

        switch before.supplyState {
        case .supplied:
            recoverDivision(
                at: index,
                hp: suppliedResupplyHPRecovery,
                in: &state
            )
        case .lowSupply:
            break
        case .encircled:
            break
        }

        let after = state.divisions[index]
        let hpRecovered = after.hp - before.hp

        if hpRecovered > 0 {
            state.appendEvent(
                "\(after.name) 粮道恢复，补员 +\(hpRecovered)。"
            )
        } else if isBesieged(after, in: state) {
            state.appendEvent("\(after.name) 仍在围城中，无法自动恢复。")
        } else {
            state.appendEvent("\(after.name) 当前\(after.supplyState.displayName)，无法自动恢复。")
        }
    }

    func resolveRetreat(for divisionId: String, in state: inout GameState) {
        guard let index = state.divisionIndex(id: divisionId) else {
            return
        }

        let division = state.divisions[index]
        if let destination = retreatDestination(for: division, in: state) {
            let origin = division.coord
            state.divisions[index].coord = destination
            if let direction = origin.direction(to: destination) {
                state.divisions[index].facing = direction
            }
            state.divisions[index].beginRetreat(to: destination)
            state.appendEvent(
                "\(division.name) 从前线撤至后方地块。"
            )
        } else {
            state.divisions[index].hp = max(1, state.divisions[index].hp - failedRetreatHPLoss)
            state.appendEvent(
                "\(division.name) 撤退失败，兵力 -\(failedRetreatHPLoss)。"
            )
        }
    }

    func advanceRetreats(in state: inout GameState) {
        let retreatingIds = state.divisions
            .filter(\.isRetreating)
            .map(\.id)

        for divisionId in retreatingIds {
            _ = advanceRetreatStatusIfNeeded(for: divisionId, in: &state)
        }
    }

    func applyEncirclementAttrition(in state: inout GameState) {
        for index in state.divisions.indices where state.divisions[index].supplyState == .encircled {
            let beforeHP = state.divisions[index].hp

            state.divisions[index].hp = max(1, beforeHP - encircledHPLoss)

            let hpLost = beforeHP - state.divisions[index].hp
            if hpLost > 0 {
                state.appendEvent(
                    "\(state.divisions[index].name) 遭围困损耗，兵力 -\(hpLost)。"
                )
            }
        }
    }

    func hasSupplyLine(for division: Division, in state: GameState) -> Bool {
        effectiveSupplyAnchors(for: division.faction, in: state).contains { coord in
            supplyPathCost(from: division.coord, to: coord, for: division.faction, in: state) <= maxSupplyPathCost
        }
    }

    func supplyState(for division: Division, in state: GameState) -> SupplyState {
        if hasSupplyLine(for: division, in: state) {
            return .supplied
        }

        if isBesieged(division, in: state) {
            return .encircled
        }

        if isEncircled(division, in: state) {
            return .encircled
        }

        return .lowSupply
    }

    func isBesieged(_ division: Division, in state: GameState) -> Bool {
        guard !hasSupplyLine(for: division, in: state),
              isFortifiedSettlement(at: division.coord, in: state),
              hasHostileAdjacentUnit(to: division.coord, faction: division.faction, in: state) else {
            return false
        }

        return true
    }

    func isEncircled(_ division: Division, in state: GameState) -> Bool {
        guard !hasSupplyLine(for: division, in: state) else {
            return false
        }

        let safeExits = division.coord.neighbors.filter {
            isSafeRetreatTile($0, for: division.faction, in: state)
        }
        return safeExits.count < 2
    }

    func isSafeRetreatTile(_ coord: HexCoord, for faction: Faction, in state: GameState) -> Bool {
        guard let tile = state.map.tile(at: coord),
              state.map.contains(coord),
              tile.isPassable,
              state.division(at: coord) == nil else {
            return false
        }

        if tile.isCapturable,
           let controller = tile.controller,
           state.diplomacyState.isHostile(faction, controller) {
            return false
        }

        if movementRules.isEnemyZoneOfControl(coord, for: faction, in: state) {
            return false
        }

        return effectiveSupplyAnchors(for: faction, in: state).contains { anchor in
            supplyPathCost(from: coord, to: anchor, for: faction, in: state) <= maxSupplyPathCost
        }
    }

    func retreatDestination(for division: Division, in state: GameState) -> HexCoord? {
        let candidates = division.coord.neighbors.filter {
            isSafeRetreatTile($0, for: division.faction, in: state)
        }

        return candidates.min {
            retreatSortKey(for: $0, faction: division.faction, in: state) <
                retreatSortKey(for: $1, faction: division.faction, in: state)
        }
    }

    func supplyPathCost(from start: HexCoord, to goal: HexCoord, for faction: Faction, in state: GameState) -> Int {
        guard state.map.contains(start), state.map.contains(goal) else {
            return Int.max
        }

        var bestCost: [HexCoord: Int] = [start: 0]
        var frontier: [(coord: HexCoord, cost: Int)] = [(start, 0)]

        while !frontier.isEmpty {
            frontier.sort { $0.cost < $1.cost }
            let current = frontier.removeFirst()

            guard current.cost == bestCost[current.coord] else {
                continue
            }

            if current.coord == goal {
                return current.cost
            }

            guard let fromTile = state.map.tile(at: current.coord) else {
                continue
            }

            for direction in HexDirection.ordered {
                let next = current.coord.neighbor(in: direction)
                guard let toTile = state.map.tile(at: next),
                      state.map.contains(next),
                      toTile.isPassable,
                      canSupplyPass(through: next, tile: toTile, for: faction, in: state) else {
                    continue
                }

                var nextCost = current.cost + supplyCost(entering: toTile)
                if movementRules.hasRiverCrossing(from: fromTile, to: toTile, direction: direction) {
                    nextCost += riverSupplyCrossingCost(from: current.coord, to: next, in: state)
                }

                guard nextCost <= maxSupplyPathCost,
                      nextCost < bestCost[next, default: Int.max] else {
                    continue
                }

                bestCost[next] = nextCost
                frontier.append((next, nextCost))
            }
        }

        return Int.max
    }

    private func riverSupplyCrossingCost(from: HexCoord, to: HexCoord, in state: GameState) -> Int {
        if hasWaterTransit(at: from, in: state) || hasWaterTransit(at: to, in: state) {
            return 0
        }
        return 2
    }

    private func hasWaterTransit(at coord: HexCoord, in state: GameState) -> Bool {
        state.map.featureMarkers.contains { marker in
            marker.coord == coord && marker.kind.isWaterTransit
        }
    }

    func effectiveSupplyAnchors(for faction: Faction, in state: GameState) -> [HexCoord] {
        orderedUnique(
            state.map.supplySources(for: faction).map(\.coord) +
                controlledWaterTransitCoords(for: faction, in: state)
        )
    }

    private func controlledWaterTransitCoords(for faction: Faction, in state: GameState) -> [HexCoord] {
        state.map.featureMarkers.compactMap { marker in
            guard marker.kind.isWaterTransit,
                  let tile = state.map.tile(at: marker.coord),
                  tile.isPassable,
                  tile.controller == faction else {
                return nil
            }
            return marker.coord
        }
    }

    private func orderedUnique(_ coords: [HexCoord]) -> [HexCoord] {
        var seen: Set<HexCoord> = []
        var result: [HexCoord] = []
        for coord in coords where seen.insert(coord).inserted {
            result.append(coord)
        }
        return result
    }

    private func canSupplyPass(through coord: HexCoord, tile: HexTile, for faction: Faction, in state: GameState) -> Bool {
        if let division = state.division(at: coord), division.faction != faction {
            return false
        }

        if tile.isCapturable,
           let controller = tile.controller,
           state.diplomacyState.isHostile(faction, controller) {
            return false
        }

        if movementRules.isEnemyZoneOfControl(coord, for: faction, in: state) {
            if state.division(at: coord)?.faction == faction {
                return true
            }
            return false
        }

        return true
    }

    private func retreatSortKey(for coord: HexCoord, faction: Faction, in state: GameState) -> RetreatSortKey {
        let anchors = effectiveSupplyAnchors(for: faction, in: state)
        let pathCost = anchors
            .map { supplyPathCost(from: coord, to: $0, for: faction, in: state) }
            .min() ?? Int.max
        let sourceDistance = anchors
            .map { coord.distance(to: $0) }
            .min() ?? Int.max
        let tileCost = state.map.tile(at: coord).map(supplyCost(entering:)) ?? Int.max

        return RetreatSortKey(
            pathCost: pathCost,
            sourceDistance: sourceDistance,
            tileCost: tileCost,
            q: coord.q,
            r: coord.r
        )
    }

    private func recoverDivision(at index: Int, hp: Int, in state: inout GameState) {
        state.divisions[index].reinforceStrength(hp)
    }

    private func advanceRetreatStatusIfNeeded(for divisionId: String, in state: inout GameState) -> Bool {
        guard let index = state.divisionIndex(id: divisionId),
              state.divisions[index].isRetreating else {
            return false
        }

        let wasRetreating = state.divisions[index].isRetreating
        state.divisions[index].advanceRetreatTurn()
        if wasRetreating && !state.divisions[index].isRetreating {
            state.appendEvent("\(state.divisions[index].name) 已完成退却整顿。")
        }

        return true
    }

    private func supplyCost(entering tile: HexTile) -> Int {
        if tile.hasRoad {
            return 1
        }

        switch tile.baseTerrain {
        case .mountain:
            return 3
        default:
            return 2
        }
    }

    private func hasHostileAdjacentUnit(to coord: HexCoord, faction: Faction, in state: GameState) -> Bool {
        state.divisions.contains { other in
            !other.isDestroyed &&
                state.diplomacyState.isHostile(faction, other.faction) &&
                other.coord.distance(to: coord) == 1
        }
    }

    private func isFortifiedSettlement(at coord: HexCoord, in state: GameState) -> Bool {
        guard let tile = state.map.tile(at: coord) else {
            return false
        }

        if tile.baseTerrain == .city ||
            tile.baseTerrain == .fortress ||
            tile.cityName != nil ||
            tile.fortressName != nil {
            return true
        }

        guard let regionId = state.map.region(for: coord),
              let region = state.map.region(id: regionId),
              region.city != nil else {
            return false
        }
        return coord == region.representativeHex
    }

    private func settlementName(for division: Division, in state: GameState) -> String {
        if let tile = state.map.tile(at: division.coord) {
            if let name = tile.cityName ?? tile.fortressName {
                return name
            }
        }

        if let regionId = state.map.region(for: division.coord),
           let region = state.map.region(id: regionId) {
            return region.city?.name ?? region.name
        }

        return "当前位置"
    }
}

private struct RetreatSortKey: Comparable {
    let pathCost: Int
    let sourceDistance: Int
    let tileCost: Int
    let q: Int
    let r: Int

    static func < (lhs: RetreatSortKey, rhs: RetreatSortKey) -> Bool {
        if lhs.pathCost != rhs.pathCost {
            return lhs.pathCost < rhs.pathCost
        }

        if lhs.sourceDistance != rhs.sourceDistance {
            return lhs.sourceDistance < rhs.sourceDistance
        }

        if lhs.tileCost != rhs.tileCost {
            return lhs.tileCost < rhs.tileCost
        }

        if lhs.q != rhs.q {
            return lhs.q < rhs.q
        }

        return lhs.r < rhs.r
    }
}
