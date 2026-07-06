import Foundation

struct MapEditorExportResult: Equatable {
    let scenarioFileName: String
    let regionFileName: String
    let scenarioDefinition: ScenarioDefinition
    let regionDataSet: RegionDataSet
    let scenarioData: Data
    let regionData: Data
}

struct MapEditorExportMetadata: Equatable {
    let factions: [String]
    let maxTurns: Int
    let initialTurn: Int
    let initialPhase: String
    let playerFaction: String
    let aiFaction: String
    let keyLocations: [KeyLocationDefinition]
    let objectives: [ObjectiveDefinition]
    let victoryConditions: [VictoryConditionDefinition]
    let dataNotes: [String]

    init(
        factions: [String],
        maxTurns: Int,
        initialTurn: Int,
        initialPhase: String,
        playerFaction: String,
        aiFaction: String,
        keyLocations: [KeyLocationDefinition] = [],
        objectives: [ObjectiveDefinition] = [],
        victoryConditions: [VictoryConditionDefinition] = [],
        dataNotes: [String]
    ) {
        self.factions = factions
        self.maxTurns = maxTurns
        self.initialTurn = initialTurn
        self.initialPhase = initialPhase
        self.playerFaction = playerFaction
        self.aiFaction = aiFaction
        self.keyLocations = keyLocations
        self.objectives = objectives
        self.victoryConditions = victoryConditions
        self.dataNotes = dataNotes
    }

    init(scenario: ScenarioDefinition) {
        self.init(
            factions: scenario.factions,
            maxTurns: scenario.maxTurns,
            initialTurn: scenario.initialTurn,
            initialPhase: scenario.initialPhase,
            playerFaction: scenario.playerFaction,
            aiFaction: scenario.aiFaction,
            keyLocations: scenario.keyLocations,
            objectives: scenario.objectives,
            victoryConditions: scenario.victoryConditions,
            dataNotes: scenario.dataNotes
        )
    }

    static func inferred(for document: MapEditorDocument) -> MapEditorExportMetadata {
        if document.id.hasPrefix("wude_618") {
            return .wude618Default
        }
        if document.id.localizedCaseInsensitiveContains("suitang")
            || document.displayName.localizedStandardContains("隋唐") {
            return .suitangDraft
        }
        if document.id.localizedCaseInsensitiveContains("legacy")
            || document.id.localizedCaseInsensitiveContains("ardennes")
            || document.id.localizedCaseInsensitiveContains("wwii")
            || document.displayName.localizedStandardContains("阿登")
            || document.displayName.localizedStandardContains("旧战局") {
            return .legacyArdennes
        }
        return .suitangDraft
    }

    static let suitangDraft = MapEditorExportMetadata(
        factions: Faction.suitangTurnOrder.map(\.rawValue),
        maxTurns: 24,
        initialTurn: 1,
        initialPhase: GamePhase.playerCommand.rawValue,
        playerFaction: Faction.tang.rawValue,
        aiFaction: Faction.luoyangSui.rawValue,
        dataNotes: [
            "由地图编辑器生成，供隋唐默认战局资源桥使用。",
            "地块仍是战术权威；州郡和方面只作为战略聚合与初始归属。"
        ]
    )

    static let wude618Default = MapEditorExportMetadata(
        factions: Faction.suitangTurnOrder.map(\.rawValue),
        maxTurns: 24,
        initialTurn: 1,
        initialPhase: GamePhase.playerCommand.rawValue,
        playerFaction: Faction.tang.rawValue,
        aiFaction: Faction.luoyangSui.rawValue,
        victoryConditions: [
            VictoryConditionDefinition(
                id: "vc_tang_hold_changan",
                type: "holdObjective",
                faction: Faction.tang.rawValue,
                objectiveId: "obj_changan",
                objectiveIds: nil,
                targetFaction: nil,
                targetTemplateIds: nil,
                turns: nil,
                turn: 24,
                count: nil,
                status: "active",
                description: "唐在终局仍控制长安。"
            ),
            VictoryConditionDefinition(
                id: "vc_tang_take_luoyang_luokou",
                type: "controlObjectives",
                faction: Faction.tang.rawValue,
                objectiveId: nil,
                objectiveIds: ["obj_luoyang", "obj_luokou"],
                targetFaction: nil,
                targetTemplateIds: nil,
                turns: nil,
                turn: nil,
                count: nil,
                status: "active",
                description: "唐控制洛阳和洛口仓。"
            ),
            VictoryConditionDefinition(
                id: "vc_luoyang_break_tongguan",
                type: "controlObjective",
                faction: Faction.luoyangSui.rawValue,
                objectiveId: "obj_tongguan",
                objectiveIds: nil,
                targetFaction: nil,
                targetTemplateIds: nil,
                turns: nil,
                turn: nil,
                count: nil,
                status: "active",
                description: "洛阳隋夺取潼关，打开关中。"
            )
        ],
        dataNotes: suitangDraft.dataNotes
    )

    static let legacyArdennes = MapEditorExportMetadata(
        factions: Faction.legacyCombatants.map(\.rawValue),
        maxTurns: 12,
        initialTurn: 1,
        initialPhase: GamePhase.alliedPlayer.rawValue,
        playerFaction: Faction.allies.rawValue,
        aiFaction: Faction.germany.rawValue,
        dataNotes: [
            "由地图编辑器生成，保留旧战局兼容资源。",
            "州郡邻接、道路边和代表地块在导出时生成。"
        ]
    )
}

enum MapEditorExportError: Error, CustomStringConvertible, Equatable {
    case unassignedHex(HexCoord)
    case emptyRegion(RegionId)
    case missingRegion(RegionId)
    case invalidTerrain(BaseTerrain)
    case encodingFailed(String)

    var description: String {
        switch self {
        case .unassignedHex:
            return "有地块尚未分配州郡，请检查地图空缺。"
        case .emptyRegion:
            return "有州郡尚未包含任何地块。"
        case .missingRegion:
            return "有地块引用了尚未定义的州郡。"
        case .invalidTerrain:
            return "有地形暂不能导出。"
        case .encodingFailed:
            return "战局数据写出失败，请检查当前文档。"
        }
    }
}

enum MapEditorExporter {
    static func export(
        document: MapEditorDocument,
        scenarioFileName: String? = nil,
        regionFileName: String? = nil,
        metadata: MapEditorExportMetadata? = nil
    ) throws -> MapEditorExportResult {
        try validateAssignable(document)
        let regionDataSet = try makeRegionDataSet(from: document)
        let resolvedMetadata = metadata ?? .inferred(for: document)
        let scenarioDefinition = makeScenarioDefinition(from: document, metadata: resolvedMetadata)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return MapEditorExportResult(
                scenarioFileName: scenarioFileName ?? "\(document.id)_scenario",
                regionFileName: regionFileName ?? "\(document.id)_regions",
                scenarioDefinition: scenarioDefinition,
                regionDataSet: regionDataSet,
                scenarioData: try encoder.encode(scenarioDefinition),
                regionData: try encoder.encode(regionDataSet)
            )
        } catch {
            throw MapEditorExportError.encodingFailed("encoding")
        }
    }

    static func write(_ result: MapEditorExportResult, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try result.scenarioData.write(
            to: directory.appendingPathComponent(result.scenarioFileName).appendingPathExtension("json"),
            options: .atomic
        )
        try result.regionData.write(
            to: directory.appendingPathComponent(result.regionFileName).appendingPathExtension("json"),
            options: .atomic
        )
    }

    private static func validateAssignable(_ document: MapEditorDocument) throws {
        for hex in document.sortedHexes where hex.regionId == nil {
            throw MapEditorExportError.unassignedHex(hex.coord)
        }

        for regionId in Set(document.hexes.values.compactMap(\.regionId)) where document.regions[regionId] == nil {
            throw MapEditorExportError.missingRegion(regionId)
        }
    }

    private static func makeScenarioDefinition(
        from document: MapEditorDocument,
        metadata: MapEditorExportMetadata
    ) -> ScenarioDefinition {
        let generatedObjectives = document.sortedHexes.compactMap { hex -> ObjectiveDefinition? in
            guard let objectiveId = hex.objectiveId else { return nil }
            return ObjectiveDefinition(
                id: objectiveId,
                name: exportDisplayName(hex.cityName ?? hex.fortressName, fallback: "未命名胜负地点"),
                kind: hex.terrain == .fortress ? ObjectiveType.fortress.rawValue : ObjectiveType.city.rawValue,
                coord: HexCoordDefinition(q: hex.coord.q, r: hex.coord.r),
                points: 1
            )
        }

        let generatedKeyLocations = document.sortedHexes.compactMap { hex -> KeyLocationDefinition? in
            guard !document.isKeyLocationSuppressed(at: hex.coord) else { return nil }
            guard hex.cityName != nil || hex.fortressName != nil || hex.isSupplySource else { return nil }
            let name = exportDisplayName(hex.cityName ?? hex.fortressName, fallback: "未命名粮仓")
            return KeyLocationDefinition(
                id: keyLocationId(for: hex),
                name: name,
                kind: keyLocationKind(for: hex),
                coord: HexCoordDefinition(q: hex.coord.q, r: hex.coord.r),
                faction: hex.supplyFaction?.rawValue ?? hex.controller?.rawValue,
                objectiveId: hex.objectiveId
            )
        }
        let documentKeyLocations = document.keyLocations.compactMap { location -> KeyLocationDefinition? in
            guard document.contains(location.coord),
                  !document.isKeyLocationSuppressed(at: location.coord) else {
                return nil
            }
            return KeyLocationDefinition(
                id: location.id,
                name: exportDisplayName(location.name, fallback: "未命名关键地点"),
                kind: location.kind,
                coord: HexCoordDefinition(q: location.coord.q, r: location.coord.r),
                faction: location.faction?.rawValue,
                objectiveId: location.objectiveId
            )
        }
        let metadataKeyLocations = document.keyLocationsAreAuthoritative
            ? []
            : metadata.keyLocations.filter { location in
                let coord = HexCoord(q: location.coord.q, r: location.coord.r)
                return document.contains(coord) && !document.isKeyLocationSuppressed(at: coord)
            }.map(sanitizedKeyLocation)

        let objectives = mergedObjectives(base: metadata.objectives.map(sanitizedObjective), generated: generatedObjectives)
        let keyLocations = mergedKeyLocations(
            base: documentKeyLocations,
            generated: metadataKeyLocations + generatedKeyLocations
        )

        return ScenarioDefinition(
            schemaVersion: 1,
            id: document.id,
            displayName: exportDisplayName(document.displayName, fallback: "未命名战局"),
            map: ScenarioMapDefinition(
                width: document.width,
                height: document.height,
                coordinateSystem: "axial-q-r",
                isSparse: document.isSparse,
                tiles: document.sortedHexes.map { hex in
                    ScenarioTileDefinition(
                        q: hex.coord.q,
                        r: hex.coord.r,
                        terrain: hex.terrain.rawValue,
                        hasRoad: hex.hasRoad,
                        riverEdges: [],
                        controller: hex.controller?.rawValue ?? "neutral",
                        cityName: exportOptionalDisplayName(hex.cityName),
                        fortressName: exportOptionalDisplayName(hex.fortressName),
                        isSupplySource: hex.isSupplySource,
                        supplyFaction: hex.supplyFaction?.rawValue,
                        objectiveId: hex.objectiveId,
                        regionId: hex.regionId?.rawValue
                    )
                }
            ),
            factions: metadata.factions,
            maxTurns: metadata.maxTurns,
            initialTurn: metadata.initialTurn,
            initialPhase: metadata.initialPhase,
            playerFaction: metadata.playerFaction,
            aiFaction: metadata.aiFaction,
            keyLocations: keyLocations,
            objectives: objectives,
            initialUnits: document.initialUnits.map { unit in
                InitialUnitDefinition(
                    id: unit.id,
                    name: exportDisplayName(unit.name, fallback: "未命名军队"),
                    faction: unit.faction.rawValue,
                    templateId: unit.templateId,
                    coord: HexCoordDefinition(q: unit.coord.q, r: unit.coord.r),
                    facing: unit.facing.rawValue,
                    hp: unit.hp,
                    retreatMode: unit.retreatMode.rawValue,
                    supplyState: unit.supplyState.rawValue,
                    assignedAgentId: unit.assignedAgentId
                )
            },
            victoryConditions: metadata.victoryConditions.map(sanitizedVictoryCondition),
            dataNotes: metadata.dataNotes.map { exportDisplayText($0, fallback: "地图编辑器导出说明。") }
        )
    }

    private static func keyLocationId(for hex: MapEditorHex) -> String {
        if let objectiveId = hex.objectiveId {
            return "loc_\(objectiveId.removingPrefix("obj_"))"
        }
        return "loc_\(hex.coord.mapEditorKey.replacingOccurrences(of: ",", with: "_"))"
    }

    private static func keyLocationKind(for hex: MapEditorHex) -> String {
        if hex.isSupplySource {
            return ObjectiveType.supply.rawValue
        }
        if hex.terrain == .fortress {
            return ObjectiveType.fortress.rawValue
        }
        return ObjectiveType.city.rawValue
    }

    private static func mergedObjectives(
        base: [ObjectiveDefinition],
        generated: [ObjectiveDefinition]
    ) -> [ObjectiveDefinition] {
        let baseIds = Set(base.map(\.id))
        return base + generated.filter { !baseIds.contains($0.id) }
    }

    private static func mergedKeyLocations(
        base: [KeyLocationDefinition],
        generated: [KeyLocationDefinition]
    ) -> [KeyLocationDefinition] {
        var existingIds = Set(base.map(\.id))
        var existingObjectiveIds = Set(base.compactMap(\.objectiveId))
        var existingCoords = Set(base.map { "\($0.coord.q),\($0.coord.r)" })
        var result = base

        for location in generated {
            let coordKey = "\(location.coord.q),\(location.coord.r)"
            if existingIds.contains(location.id)
                || (location.objectiveId.map { existingObjectiveIds.contains($0) } ?? false)
                || existingCoords.contains(coordKey) {
                continue
            }
            result.append(location)
            existingIds.insert(location.id)
            if let objectiveId = location.objectiveId {
                existingObjectiveIds.insert(objectiveId)
            }
            existingCoords.insert(coordKey)
        }

        return result
    }

    private static func makeRegionDataSet(from document: MapEditorDocument) throws -> RegionDataSet {
        let hexesByRegion = Dictionary(grouping: document.sortedHexes) { $0.regionId }
        var neighborMap: [RegionId: Set<RegionId>] = [:]
        var edgeRoadFlags: [String: Bool] = [:]

        for hex in document.sortedHexes {
            guard let regionA = hex.regionId else { continue }
            for neighborCoord in hex.coord.neighbors {
                guard let neighborHex = document.hexes[neighborCoord],
                      let regionB = neighborHex.regionId,
                      regionA != regionB else {
                    continue
                }

                neighborMap[regionA, default: []].insert(regionB)
                neighborMap[regionB, default: []].insert(regionA)
                let key = edgeKey(regionA, regionB)
                edgeRoadFlags[key] = (edgeRoadFlags[key] ?? false) || (hex.hasRoad && neighborHex.hasRoad)
            }
        }

        let regionDefinitions = try document.regions.values.sorted { $0.id.rawValue < $1.id.rawValue }.map { draft in
            guard let regionHexes = hexesByRegion[draft.id], !regionHexes.isEmpty else {
                throw MapEditorExportError.emptyRegion(draft.id)
            }

            let representativeHex = representativeHex(for: regionHexes)
            let terrain = dominantTerrain(in: regionHexes)
            let cityHex = regionHexes.first { $0.cityName != nil || $0.terrain == .city || $0.fortressName != nil }
            return RegionNodeDefinition(
                id: draft.id,
                name: exportDisplayName(draft.name, fallback: "未命名州郡"),
                owner: draft.owner,
                controller: draft.controller,
                theaterId: document.regionTheaterAssignments[draft.id],
                assignedGeneralId: draft.assignedGeneralId,
                terrain: terrain,
                neighbors: (neighborMap[draft.id] ?? []).sorted { $0.rawValue < $1.rawValue },
                displayHexes: regionHexes.map(\.coord).sortedByMapOrder(),
                representativeHex: representativeHex,
                city: cityHex.map {
                    CityInfoDefinition(
                        name: exportDisplayName($0.cityName ?? $0.fortressName ?? draft.name, fallback: "未命名城邑"),
                        victoryPoints: $0.objectiveId == nil ? 0 : 1,
                        isCapital: false
                    )
                },
                infrastructure: draft.infrastructure,
                supplyValue: draft.supplyValue,
                factories: draft.factories,
                resources: [],
                coreOf: draft.coreOf,
                occupationState: nil,
                isPassable: true
            )
        }

        let edges = edgeRoadFlags.keys.sorted().compactMap { key -> RegionEdgeDefinition? in
            let parts = key.split(separator: "|").map(String.init)
            guard parts.count == 2 else { return nil }
            return RegionEdgeDefinition(
                from: RegionId(parts[0]),
                to: RegionId(parts[1]),
                hasRoad: edgeRoadFlags[key] ?? false,
                hasRiverCrossing: false,
                movementCostModifier: 0
            )
        }

        let supplySources = document.sortedHexes.compactMap { hex -> RegionSupplySourceDefinition? in
            guard hex.isSupplySource,
                  let faction = hex.supplyFaction,
                  let regionId = hex.regionId else {
                return nil
            }
            return RegionSupplySourceDefinition(
                id: "supply_\(hex.coord.mapEditorKey.replacingOccurrences(of: ",", with: "_"))",
                faction: faction,
                regionId: regionId
            )
        }

        let objectives = document.sortedHexes.compactMap { hex -> RegionObjectiveDefinition? in
            guard let objectiveId = hex.objectiveId, let regionId = hex.regionId else { return nil }
            return RegionObjectiveDefinition(
                id: objectiveId,
                name: exportDisplayName(hex.cityName ?? hex.fortressName, fallback: "未命名胜负地点"),
                regionId: regionId,
                type: hex.terrain == .fortress ? .fortress : .city,
                victoryPoints: 1,
                mainObjective: false
            )
        }

        return RegionDataSet(
            schemaVersion: 2,
            scenarioId: document.id,
            displayName: "\(exportDisplayName(document.displayName, fallback: "未命名战局")) 州郡数据",
            hexToRegion: Dictionary(uniqueKeysWithValues: document.sortedHexes.compactMap { hex in
                hex.regionId.map { (hex.coord.mapEditorKey, $0) }
            }),
            regions: regionDefinitions,
            edges: edges,
            supplySources: supplySources,
            objectives: objectives
        )
    }

    private static func representativeHex(for hexes: [MapEditorHex]) -> HexCoord {
        let q = Double(hexes.reduce(0) { $0 + $1.coord.q }) / Double(hexes.count)
        let r = Double(hexes.reduce(0) { $0 + $1.coord.r }) / Double(hexes.count)
        return hexes.min { lhs, rhs in
            let lhsDistance = pow(Double(lhs.coord.q) - q, 2) + pow(Double(lhs.coord.r) - r, 2)
            let rhsDistance = pow(Double(rhs.coord.q) - q, 2) + pow(Double(rhs.coord.r) - r, 2)
            if lhsDistance == rhsDistance {
                return lhs.coord.mapEditorKey < rhs.coord.mapEditorKey
            }
            return lhsDistance < rhsDistance
        }?.coord ?? hexes[0].coord
    }

    private static func dominantTerrain(in hexes: [MapEditorHex]) -> BaseTerrain {
        let counts = Dictionary(grouping: hexes, by: \.terrain).mapValues(\.count)
        return counts.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value
        }.first?.key ?? .plain
    }

    private static func sanitizedKeyLocation(_ location: KeyLocationDefinition) -> KeyLocationDefinition {
        KeyLocationDefinition(
            id: location.id,
            name: exportDisplayName(location.name, fallback: "未命名关键地点"),
            kind: location.kind,
            coord: location.coord,
            faction: location.faction,
            objectiveId: location.objectiveId
        )
    }

    private static func sanitizedObjective(_ objective: ObjectiveDefinition) -> ObjectiveDefinition {
        ObjectiveDefinition(
            id: objective.id,
            name: exportDisplayName(objective.name, fallback: "未命名胜负地点"),
            kind: objective.kind,
            coord: objective.coord,
            points: objective.points
        )
    }

    private static func sanitizedVictoryCondition(_ condition: VictoryConditionDefinition) -> VictoryConditionDefinition {
        VictoryConditionDefinition(
            id: condition.id,
            type: condition.type,
            faction: condition.faction,
            objectiveId: condition.objectiveId,
            objectiveIds: condition.objectiveIds,
            targetFaction: condition.targetFaction,
            targetTemplateIds: condition.targetTemplateIds,
            turns: condition.turns,
            turn: condition.turn,
            count: condition.count,
            status: condition.status,
            description: exportDisplayText(condition.description, fallback: "胜负条件。")
        )
    }

    private static func exportOptionalDisplayName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let sanitized = sanitizeRawExportIdentifier(in: trimmed)
        return sanitized.isEmpty ? nil : sanitized
    }

    private static func exportDisplayName(_ name: String?, fallback: String) -> String {
        exportOptionalDisplayName(name) ?? fallback
    }

    private static func exportDisplayText(_ text: String, fallback: String) -> String {
        let sanitized = exportOptionalDisplayName(text)
        return sanitized ?? fallback
    }

    private static func sanitizeRawExportIdentifier(in text: String) -> String {
        text
            .replacingOccurrences(
                of: #"\bregion_[A-Za-z0-9_\-]+\b"#,
                with: "相关州郡",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(theater|front_zone)_[A-Za-z0-9_\-]+\b"#,
                with: "相关方面",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(objective|obj|hex|loc|supply|vc)_[A-Za-z0-9_\-]+\b"#,
                with: "相关地点",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(division|unit)_[A-Za-z0-9_\-]+\b"#,
                with: "相关军队",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(agent|general|command)_[A-Za-z0-9_\-]+\b"#,
                with: "相关指令记录",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(germany|france|allied|axis|ger|all)_[A-Za-z0-9_\-]+\b"#,
                with: "相关旧战局",
                options: .regularExpression
            )
            .replacingOccurrences(of: "巴斯托涅", with: "旧战局要地")
            .replacingOccurrences(of: "圣维特", with: "旧战局要地")
            .replacingOccurrences(of: "色当", with: "旧战局要地")
            .replacingOccurrences(of: "阿登", with: "旧战局")
            .replacingOccurrences(of: "Ardennes", with: "旧战局")
            .replacingOccurrences(of: "ardennes", with: "旧战局")
            .replacingOccurrences(of: "Bastogne", with: "旧战局要地")
            .replacingOccurrences(of: "bastogne", with: "旧战局要地")
            .replacingOccurrences(of: "St. Vith", with: "旧战局要地")
            .replacingOccurrences(of: "St Vith", with: "旧战局要地")
            .replacingOccurrences(of: "st. vith", with: "旧战局要地")
            .replacingOccurrences(of: "st vith", with: "旧战局要地")
            .replacingOccurrences(of: "Sedan", with: "旧战局要地")
            .replacingOccurrences(of: "sedan", with: "旧战局要地")
            .replacingOccurrences(
                of: #"\b(German|Germany|germany|Allied|Allies|allies|Axis|axis|United States|USA|US)\b"#,
                with: "旧剧本",
                options: .regularExpression
            )
            .replacingOccurrences(of: "德军", with: "旧剧本")
            .replacingOccurrences(of: "盟军", with: "旧剧本")
            .replacingOccurrences(
                of: #"\b(Panzer|Infantry|Artillery|Anti-Tank)\b"#,
                with: "军队",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bMotorized\b"#,
                with: "机动军队",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bGarrison\b"#,
                with: "守军",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bSupply\b"#,
                with: "补给",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(Heinz Guderian|Guderian)\b"#,
                with: "历史总管",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bField Marshal\b"#,
                with: "行军总管",
                options: .regularExpression
            )
            .replacingOccurrences(of: "MapEditor", with: "地图编辑器")
            .replacingOccurrences(of: "schema", with: "数据格式")
            .replacingOccurrences(of: "rawValue", with: "内部值")
            .replacingOccurrences(of: "JSON", with: "数据文件")
            .replacingOccurrences(of: " id", with: " 内部编号")
            .replacingOccurrences(of: "战区", with: "方面")
    }

    private static func edgeKey(_ a: RegionId, _ b: RegionId) -> String {
        [a.rawValue, b.rawValue].sorted().joined(separator: "|")
    }
}

private extension Array where Element == HexCoord {
    func sortedByMapOrder() -> [HexCoord] {
        sorted { lhs, rhs in
            lhs.r == rhs.r ? lhs.q < rhs.q : lhs.r < rhs.r
        }
    }
}

private extension String {
    func removingPrefix(_ prefix: String) -> String {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : self
    }
}
