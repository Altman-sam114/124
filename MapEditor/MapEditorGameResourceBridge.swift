import Foundation

enum MapEditorGameResourceBridgeError: Error, CustomStringConvertible {
    case missingTerrain(String)
    case missingResource(URL)

    var description: String {
        switch self {
        case .missingTerrain:
            return "游戏资源中存在地图工具暂不支持的地形。"
        case .missingResource:
            return "缺少默认战局资源。"
        }
    }
}

struct MapEditorGameResourceImportDiagnostic: Equatable {
    let message: String
}

struct MapEditorGameResourceImportResult: Equatable {
    let document: MapEditorDocument
    let diagnostics: [MapEditorGameResourceImportDiagnostic]

    func statusMessage(successMessage: String) -> String {
        guard !diagnostics.isEmpty else {
            return successMessage
        }
        let summary = diagnostics.prefix(3).map(\.message).joined(separator: "；")
        let suffix = diagnostics.count > 3 ? "；另有 \(diagnostics.count - 3) 项导入诊断。" : ""
        return "\(successMessage) 已跳过 \(diagnostics.count) 项异常资料：\(summary)\(suffix)"
    }
}

enum MapEditorGameResourceBridge {
    static let scenarioResourceName = "wude_618_scenario"
    static let regionResourceName = "wude_618_regions"

    static var gameDataDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "WWIIHexV0")
            .appending(path: "Data")
    }

    static func loadDefaultDocument() throws -> MapEditorDocument {
        try loadDefaultDocumentResult().document
    }

    static func loadDefaultDocumentResult() throws -> MapEditorGameResourceImportResult {
        let scenarioURL = gameDataDirectory.appending(path: scenarioResourceName).appendingPathExtension("json")
        let regionURL = gameDataDirectory.appending(path: regionResourceName).appendingPathExtension("json")
        guard FileManager.default.fileExists(atPath: scenarioURL.path) else {
            throw MapEditorGameResourceBridgeError.missingResource(scenarioURL)
        }
        guard FileManager.default.fileExists(atPath: regionURL.path) else {
            throw MapEditorGameResourceBridgeError.missingResource(regionURL)
        }

        let decoder = JSONDecoder()
        let scenario = try decoder.decode(ScenarioDefinition.self, from: Data(contentsOf: scenarioURL))
        let regionData = try decoder.decode(RegionDataSet.self, from: Data(contentsOf: regionURL))
        return try makeDocument(scenario: scenario, regionData: regionData)
    }

    static func overwriteDefaultGameResources(document: MapEditorDocument) throws -> MapEditorExportResult {
        let result = try MapEditorExporter.export(
            document: document,
            scenarioFileName: scenarioResourceName,
            regionFileName: regionResourceName,
            metadata: defaultExportMetadata()
        )
        try MapEditorExporter.write(result, to: gameDataDirectory)
        return result
    }

    static func exportMetadata(for document: MapEditorDocument) -> MapEditorExportMetadata? {
        guard document.id.hasPrefix("wude_618") else { return nil }
        return defaultExportMetadata()
    }

    static func defaultExportMetadata() -> MapEditorExportMetadata? {
        let scenarioURL = gameDataDirectory.appending(path: scenarioResourceName).appendingPathExtension("json")
        guard FileManager.default.fileExists(atPath: scenarioURL.path),
              let data = try? Data(contentsOf: scenarioURL),
              let scenario = try? JSONDecoder().decode(ScenarioDefinition.self, from: data) else {
            return nil
        }
        return MapEditorExportMetadata(scenario: scenario)
    }

    private static func makeDocument(
        scenario: ScenarioDefinition,
        regionData: RegionDataSet
    ) throws -> MapEditorGameResourceImportResult {
        let regionMapping = regionData.toHexToRegion()
        var hexes: [HexCoord: MapEditorHex] = [:]
        var diagnostics: [MapEditorGameResourceImportDiagnostic] = []
        for tile in scenario.map.tiles {
            let coord = HexCoord(q: tile.q, r: tile.r)
            guard let terrain = BaseTerrain(rawValue: tile.terrain) else {
                throw MapEditorGameResourceBridgeError.missingTerrain(tile.terrain)
            }
            hexes[coord] = MapEditorHex(
                coord: coord,
                terrain: terrain,
                hasRoad: tile.hasRoad,
                controller: Faction(rawValue: tile.controller),
                cityName: tile.cityName,
                fortressName: tile.fortressName,
                isSupplySource: tile.isSupplySource,
                supplyFaction: tile.supplyFaction.flatMap(Faction.init(rawValue:)),
                objectiveId: tile.objectiveId,
                regionId: regionMapping[coord] ?? tile.regionId.map { RegionId($0) }
            )
        }

        let regions = Dictionary(uniqueKeysWithValues: regionData.regions.map { definition in
            (
                definition.id,
                MapEditorRegionDraft(
                    id: definition.id,
                    name: definition.name,
                    owner: definition.owner,
                    controller: definition.controller,
                    infrastructure: definition.infrastructure,
                    supplyValue: definition.supplyValue,
                    factories: definition.factories,
                    coreOf: definition.coreOf,
                    assignedGeneralId: definition.assignedGeneralId
                )
            )
        })
        let regionTheaterAssignments = Dictionary(uniqueKeysWithValues: regionData.regions.compactMap { definition in
            definition.theaterId.map { (definition.id, $0) }
        })
        let theaters = Dictionary(uniqueKeysWithValues: Set(regionTheaterAssignments.values).map { theaterId in
            (theaterId, MapEditorTheaterDraft(id: theaterId))
        })
        var units: [MapEditorUnitDraft] = []
        for unit in scenario.initialUnits {
            guard let faction = Faction(rawValue: unit.faction) else {
                diagnostics.append(
                    MapEditorGameResourceImportDiagnostic(
                        message: "军队 \(unit.id) 的势力值 \(unit.faction) 无法识别。"
                    )
                )
                continue
            }
            units.append(
                MapEditorUnitDraft(
                    id: unit.id,
                    name: unit.name,
                    faction: faction,
                    templateId: unit.templateId,
                    coord: HexCoord(q: unit.coord.q, r: unit.coord.r),
                    facing: HexDirection(rawValue: unit.facing) ?? .west,
                    hp: unit.hp,
                    retreatMode: unit.retreatMode.flatMap(RetreatMode.init(rawValue:)) ?? .retreatable,
                    supplyState: SupplyState(rawValue: unit.supplyState) ?? .supplied,
                    assignedAgentId: unit.assignedAgentId
                )
            )
        }
        let keyLocations = scenario.keyLocations.map { location in
            MapEditorKeyLocationDraft(
                id: location.id,
                name: location.name,
                kind: location.kind,
                coord: HexCoord(q: location.coord.q, r: location.coord.r),
                faction: location.faction.flatMap(Faction.init(rawValue:)),
                objectiveId: location.objectiveId
            )
        }

        return MapEditorGameResourceImportResult(
            document: MapEditorDocument(
                id: scenario.id,
                displayName: scenario.displayName,
                width: scenario.map.width,
                height: scenario.map.height,
                hexes: hexes,
                regions: regions,
                theaters: theaters,
                regionTheaterAssignments: regionTheaterAssignments,
                initialUnits: units,
                keyLocations: keyLocations,
                keyLocationsAreAuthoritative: true
            ),
            diagnostics: diagnostics
        )
    }
}
