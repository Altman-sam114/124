import Foundation

struct BoardRenderState: Equatable {
    let gameState: GameState
    let viewerFaction: Faction
    let selectedUnitId: String?
    let selectedHex: HexCoord?
    let selectedRegionId: RegionId?
    let movementHighlights: Set<HexCoord>
    let attackHighlights: Set<HexCoord>
    let mapDisplayLayer: MapDisplayLayer
    let observerModeEnabled: Bool
    let recentDirectiveRecords: [WarDirectiveRecord]

    var displayAdapter: MapDisplayAdapter {
        MapDisplayAdapter(state: gameState, revealAll: observerModeEnabled)
    }
}

enum BoardSceneAdapter {
    static func renderState(from container: AppContainer) -> BoardRenderState {
        BoardRenderState(
            gameState: container.gameState,
            viewerFaction: container.playerFaction,
            selectedUnitId: container.selectedUnitId,
            selectedHex: container.selectedHex,
            selectedRegionId: container.selectedRegionId,
            movementHighlights: container.movementHighlights,
            attackHighlights: container.attackHighlights,
            mapDisplayLayer: container.mapDisplayLayer,
            observerModeEnabled: container.observerModeEnabled,
            recentDirectiveRecords: recentDirectiveRecords(from: container)
        )
    }

    private static func recentDirectiveRecords(from container: AppContainer) -> [WarDirectiveRecord] {
        let source = container.lastWarDirectiveRecords.isEmpty
            ? container.gameState.warDirectiveRecords
            : container.lastWarDirectiveRecords
        return Array(source.suffix(12))
    }

    static func regionId(for hex: HexCoord, in state: GameState) -> RegionId? {
        MapDisplayAdapter(state: state).regionId(for: hex)
    }

    static func displayHexes(for regionId: RegionId, in state: GameState) -> [HexCoord] {
        MapDisplayAdapter(state: state).displayHexes(for: regionId)
    }

    static func isHighlighted(hex: HexCoord, selectedRegionId: RegionId?, in state: GameState) -> Bool {
        guard let selectedRegionId else {
            return false
        }
        return regionId(for: hex, in: state) == selectedRegionId
    }
}
