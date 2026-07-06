import Foundation

struct DataLoader {
    private let bundle: Bundle
    private let resourceDirectory: URL?
    private let decoder: JSONDecoder

    init(bundle: Bundle = .main, resourceDirectory: URL? = nil) {
        self.bundle = bundle
        self.resourceDirectory = resourceDirectory
        self.decoder = JSONDecoder()
    }

    init(resourceDirectory: URL) {
        self.init(bundle: .main, resourceDirectory: resourceDirectory)
    }

    func loadInitialGameState() -> GameState {
        if let state = try? loadGameState(
            scenarioName: "wude_618_scenario",
            regionName: "wude_618_regions",
            unitTemplatesName: "suitang_unit_templates",
            generalRegistryName: "suitang_generals"
        ) {
            return state
        }

        if let state = try? loadGameState(
            scenarioName: "ardennes_v0_scenario",
            regionName: "ardennes_v02_regions"
        ) {
            return state
        }

        var state = GameState.initial()

        // v0.2: 叠加省份数据。加载失败时 fallback 纯 hex（不破现有行为）。
        // 省份是战略层叠加，hex 仍是战术层权威；tiles/objectives/supplySources 不变。
        if let regionData = try? loadArdennesV02Regions() {
            state.map.regions = regionData.toRegions()
            state.map.hexToRegion = regionData.toHexToRegion()
            state.map.regionEdges = regionData.toRegionEdges()
            // 反向填 HexTile.regionId，让 tile.regionId == hexToRegion[tile.coord]
            for (coord, regionId) in state.map.hexToRegion {
                if var tile = state.map.tile(at: coord) {
                    tile.regionId = regionId
                    state.map.setTile(tile)
                }
            }
            state.map = RegionOccupationRules().mapByAggregatingControllers(in: state.map)
            state.theaterState = makeTheaterState(
                map: state.map,
                regionData: regionData,
                divisions: state.divisions,
                turn: state.turn
            )
            state.frontLineState = FrontLineManager().makeInitialState(
                map: state.map,
                theaterState: state.theaterState,
                divisions: state.divisions,
                turn: state.turn
            )
            let deploymentState = WarDeploymentManager().makeInitialState(
                map: state.map,
                theaterState: state.theaterState,
                divisions: state.divisions,
                turn: state.turn
            )
            state.warDeploymentState = assignGenerals(
                to: deploymentState,
                map: state.map,
                regionData: regionData
            )
        }

        return state
    }

    func loadArdennesDataSet() throws -> ScenarioDataSet {
        let dataSet = ScenarioDataSet(
            scenario: try loadScenarioDefinition(),
            terrainRules: try loadTerrainRules(),
            unitTemplates: try loadUnitTemplates(),
            generalAgents: try loadGeneralAgents()
        )
        try validate(dataSet)
        return dataSet
    }

    func loadScenarioDefinition() throws -> ScenarioDefinition {
        try loadJSON(ScenarioDefinition.self, named: "ardennes_v0_scenario")
    }

    func loadScenarioDefinition(named resourceName: String) throws -> ScenarioDefinition {
        try loadJSON(ScenarioDefinition.self, named: resourceName)
    }

    func loadRegionDataSet(named resourceName: String) throws -> RegionDataSet {
        try loadJSON(RegionDataSet.self, named: resourceName)
    }

    /// v0.34: 加载 MapEditor 直接导出的 ScenarioDefinition + RegionDataSet。
    /// 这是编辑器输出的主验收路径，不要求走旧 Ardennes 数据集的 agent/胜利条件强校验。
    func loadGameState(
        scenarioName: String,
        regionName: String,
        unitTemplatesName: String = "unit_templates",
        generalRegistryName: String = "generals"
    ) throws -> GameState {
        let scenario = try loadScenarioDefinition(named: scenarioName)
        let regionData = try loadRegionDataSet(named: regionName)
        var map = try makeMapState(from: scenario)
        try apply(regionData, to: &map)
        map = RegionOccupationRules().mapByAggregatingControllers(in: map)
        let divisions = try makeDivisions(
            from: scenario.initialUnits,
            templates: (try? loadUnitTemplates(named: unitTemplatesName)) ?? []
        )
        let turn = scenario.initialTurn

        let theaterState = makeTheaterState(
            map: map,
            regionData: regionData,
            divisions: divisions,
            turn: turn
        )
        let frontLineState = FrontLineManager().makeInitialState(
            map: map,
            theaterState: theaterState,
            divisions: divisions,
            turn: turn
        )
        let deploymentState = WarDeploymentManager().makeInitialState(
            map: map,
            theaterState: theaterState,
            divisions: divisions,
            turn: turn
        )
        let warDeploymentState = assignGenerals(
            to: deploymentState,
            map: map,
            regionData: regionData,
            registry: (try? loadGeneralRegistry(named: generalRegistryName)) ?? .empty
        )

        let initialPhase = initialPhase(for: scenario)
        let initialActiveFaction = initialActiveFaction(for: scenario, phase: initialPhase)

        return GameState(
            scenarioId: scenario.id,
            turn: turn,
            maxTurns: scenario.maxTurns,
            activeFaction: initialActiveFaction,
            playerFaction: initialPlayerFaction(for: scenario),
            phase: initialPhase,
            map: map,
            theaterState: theaterState,
            frontLineState: frontLineState,
            warDeploymentState: warDeploymentState,
            diplomacyState: DiplomacyState.initial(from: scenario.factions, turn: turn),
            divisions: divisions,
            victoryState: .ongoing,
            selectedUnitSummary: nil,
            eventLog: [
                GameLogEntry(
                    turn: turn,
                    faction: initialActiveFaction,
                    phase: initialPhase,
                    message: "已载入地图编辑器战局数据：\(scenario.displayName)。"
                )
            ]
        )
    }

    private func initialPhase(for scenario: ScenarioDefinition) -> GamePhase {
        if let phase = GamePhase(rawValue: scenario.initialPhase) {
            return phase
        }
        return scenario.id.hasPrefix("ardennes") ? .alliedPlayer : .playerCommand
    }

    private func initialPlayerFaction(for scenario: ScenarioDefinition) -> Faction {
        Faction(rawValue: scenario.playerFaction) ??
            (scenario.id.hasPrefix("ardennes") ? .allies : .tang)
    }

    private func initialActiveFaction(for scenario: ScenarioDefinition, phase: GamePhase) -> Faction {
        switch phase {
        case .alliedPlayer:
            return Faction(rawValue: scenario.playerFaction) ?? .allies
        case .germanAI:
            return Faction(rawValue: scenario.aiFaction) ?? .germany
        case .playerCommand:
            return Faction(rawValue: scenario.playerFaction) ?? .tang
        case .aiCommand:
            return Faction(rawValue: scenario.aiFaction) ?? .luoyangSui
        case .resolution:
            return Faction(rawValue: scenario.playerFaction) ?? .tang
        }
    }

    func loadTerrainRules() throws -> TerrainRuleDefinition {
        try loadJSON(TerrainRuleDefinition.self, named: "terrain_rules")
    }

    func loadUnitTemplates() throws -> [UnitTemplateDefinition] {
        try loadUnitTemplates(named: "unit_templates")
    }

    func loadUnitTemplates(named resourceName: String) throws -> [UnitTemplateDefinition] {
        try loadJSON(UnitTemplateCatalogDefinition.self, named: resourceName).templates
    }

    func loadGeneralAgents() throws -> [GeneralAgentDefinition] {
        try loadJSON(GeneralAgentCatalogDefinition.self, named: "general_agents").agents
    }

    func loadGeneralRegistry() throws -> GeneralRegistry {
        try loadGeneralRegistry(named: "generals")
    }

    func loadGeneralRegistry(named resourceName: String) throws -> GeneralRegistry {
        let catalog = try loadJSON(GeneralCatalogDefinition.self, named: resourceName)
        return GeneralRegistry(generals: catalog.generals)
    }

    func loadGeneralRegistry(for scenarioId: String) throws -> GeneralRegistry {
        if scenarioId.hasPrefix("wude_618") {
            return try loadGeneralRegistry(named: "suitang_generals")
        }
        return try loadGeneralRegistry()
    }

    /// v0.2: 加载阿登省份图数据。失败时抛 DataLoaderError。
    /// 返回的 RegionDataSet 可通过 toRegions()/toRegionEdges()/toHexToRegion() 映射到 MapState 叠加层。
    func loadArdennesV02Regions() throws -> RegionDataSet {
        try loadJSON(RegionDataSet.self, named: "ardennes_v02_regions")
    }

    /// v0.2: 校验省份数据集一致性。复用 RegionGraph.validate + hexToRegion/overlap 检查。
    /// 错误聚合为 DataLoaderError.validationFailed，便于 Agent 5 测试断言。
    func validate(_ regionData: RegionDataSet) throws {
        let regions = regionData.toRegions()
        let hexToRegion = regionData.toHexToRegion()
        let regionEdges = regionData.toRegionEdges()

        // 构临时 MapState 跑 validateRegionGraph（含 hexToRegion + overlap 检查）
        let probe = MapState(
            width: 11,
            height: 9,
            tiles: [:],
            supplySources: [],
            objectives: [],
            regions: regions,
            hexToRegion: hexToRegion,
            regionEdges: regionEdges
        )
        let errors = probe.validateRegionGraph().map { DataValidationError(message: $0.description) }
        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }
    }

    func validate(_ dataSet: ScenarioDataSet) throws {
        var errors: [DataValidationError] = []
        let scenario = dataSet.scenario

        if !scenario.map.isSparse {
            let expectedTileCount = scenario.map.width * scenario.map.height
            if scenario.map.tiles.count != expectedTileCount {
                errors.append(
                    DataValidationError(
                        message: "地图地块数量 \(scenario.map.tiles.count) 与宽高乘积 \(expectedTileCount) 不一致。"
                    )
                )
            }
        }

        let tileCoords = Set(scenario.map.tiles.map(\.coord))
        if tileCoords.count != scenario.map.tiles.count {
            errors.append(DataValidationError(message: "地图存在重复地块坐标。"))
        }

        let unitIds = scenario.initialUnits.map(\.id)
        appendDuplicateErrors(unitIds, label: "初始军队 id", to: &errors)

        let occupiedCoords = scenario.initialUnits.map(\.coord)
        if Set(occupiedCoords).count != occupiedCoords.count {
            errors.append(DataValidationError(message: "初始军队存在重叠坐标。"))
        }

        for unit in scenario.initialUnits where !tileCoords.contains(unit.coord) {
            errors.append(
                DataValidationError(
                    message: "初始军队 \(unit.id) 引用了不存在的地块（\(unit.coord.q),\(unit.coord.r)）。"
                )
            )
        }

        let templateIds = Set(dataSet.unitTemplates.map(\.id))
        appendDuplicateErrors(dataSet.unitTemplates.map(\.id), label: "军队模板 id", to: &errors)
        for unit in scenario.initialUnits where !templateIds.contains(unit.templateId) {
            errors.append(
                DataValidationError(
                    message: "初始军队 \(unit.id) 引用了未知模板 \(unit.templateId)。"
                )
            )
        }

        for template in dataSet.unitTemplates {
            let componentWeight = template.components.reduce(0.0) { $0 + $1.weight }
            if abs(componentWeight - 1.0) > 0.0001 {
                errors.append(
                    DataValidationError(
                        message: "军队模板 \(template.id) 的兵种权重合计为 \(componentWeight)，应为 1.0。"
                    )
                )
            }
        }

        let germanSupplySources = scenario.map.tiles.filter {
            $0.isSupplySource && $0.supplyFaction == "germany"
        }
        let alliedSupplySources = scenario.map.tiles.filter {
            $0.isSupplySource && $0.supplyFaction == "allies"
        }
        if germanSupplySources.isEmpty {
            errors.append(DataValidationError(message: "旧战局缺少东路势力补给源。"))
        }
        if alliedSupplySources.isEmpty {
            errors.append(DataValidationError(message: "旧战局缺少西路势力补给源。"))
        }

        let objectiveIds = scenario.objectives.map(\.id)
        appendDuplicateErrors(objectiveIds, label: "目标 id", to: &errors)
        let objectiveIdSet = Set(objectiveIds)

        let tileObjectiveIds = scenario.map.tiles.compactMap(\.objectiveId)
        appendDuplicateErrors(tileObjectiveIds, label: "地块目标 id", to: &errors)
        for objectiveId in tileObjectiveIds where !objectiveIdSet.contains(objectiveId) {
            errors.append(
                DataValidationError(
                    message: "地块目标 \(objectiveId) 未在战局目标列表中声明。"
                )
            )
        }

        for condition in scenario.victoryConditions {
            if let objectiveId = condition.objectiveId, !objectiveIdSet.contains(objectiveId) {
                errors.append(
                    DataValidationError(
                        message: "胜利条件 \(condition.id) 引用了未知目标 \(objectiveId)。"
                    )
                )
            }

            for objectiveId in condition.objectiveIds ?? [] where !objectiveIdSet.contains(objectiveId) {
                errors.append(
                    DataValidationError(
                        message: "胜利条件 \(condition.id) 引用了未知目标 \(objectiveId)。"
                    )
                )
            }
        }

        let agentIds = dataSet.generalAgents.map(\.id)
        appendDuplicateErrors(agentIds, label: "将领代理 id", to: &errors)

        if scenario.id == "ardennes_v0" {
            let unitIdSet = Set(unitIds)
            for agent in dataSet.generalAgents {
                for divisionId in agent.assignedDivisionIds where !unitIdSet.contains(divisionId) {
                    errors.append(
                        DataValidationError(
                            message: "代理 \(agent.id) 引用了未知军队 \(divisionId)。"
                        )
                    )
                }
            }

            if let guderian = dataSet.generalAgents.first(where: { $0.id == "guderian" }) {
                let germanUnitIds = Set(scenario.initialUnits.filter { $0.faction == "germany" }.map(\.id))
                let assignedDivisionIds = Set(guderian.assignedDivisionIds)
                if assignedDivisionIds != germanUnitIds {
                    errors.append(
                        DataValidationError(
                            message: "旧剧本东路代理配置必须完整覆盖东路初始军队。"
                        )
                    )
                }
            } else {
                errors.append(DataValidationError(message: "旧战局缺少东路代理配置。"))
            }
        }

        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, named resourceName: String) throws -> T {
        let url = try resourceURL(named: resourceName)
        let data = try Data(contentsOf: url)
        return try decoder.decode(T.self, from: data)
    }

    private func makeMapState(from scenario: ScenarioDefinition) throws -> MapState {
        var errors: [DataValidationError] = []
        var tiles: [HexCoord: HexTile] = [:]
        var supplySources: [SupplySource] = []
        var objectives: [Objective] = []
        let featureMarkers = scenario.keyLocations.map { location in
            MapFeatureMarker(
                id: location.id,
                name: location.name,
                kind: MapFeatureKind(rawValue: location.kind),
                coord: HexCoord(q: location.coord.q, r: location.coord.r),
                faction: location.faction.flatMap(Faction.init(rawValue:)),
                objectiveId: location.objectiveId
            )
        }

        for tileDefinition in scenario.map.tiles {
            let coord = HexCoord(q: tileDefinition.q, r: tileDefinition.r)
            guard tiles[coord] == nil else {
                errors.append(DataValidationError(message: "重复地块坐标 \(coord.q),\(coord.r)。"))
                continue
            }

            guard let terrain = BaseTerrain(rawValue: tileDefinition.terrain) else {
                errors.append(DataValidationError(message: "地块 \(coord.q),\(coord.r) 使用未知地形 \(tileDefinition.terrain)。"))
                continue
            }

            let controller = Faction(rawValue: tileDefinition.controller)
            let riverEdges = Set(tileDefinition.riverEdges.compactMap(HexDirection.init(rawValue:)))
            let regionId = tileDefinition.regionId.map { RegionId($0) }
            let tile = HexTile(
                coord: coord,
                baseTerrain: terrain,
                hasRoad: tileDefinition.hasRoad,
                riverEdges: riverEdges,
                controller: controller,
                cityName: tileDefinition.cityName,
                fortressName: tileDefinition.fortressName,
                isPassable: true,
                regionId: regionId
            )
            tiles[coord] = tile

            if tileDefinition.isSupplySource,
               let supplyFactionString = tileDefinition.supplyFaction,
               let supplyFaction = Faction(rawValue: supplyFactionString) {
                supplySources.append(
                    SupplySource(
                        id: "supply_\(coord.q)_\(coord.r)",
                        faction: supplyFaction,
                        coord: coord
                    )
                )
            }
        }

        for objectiveDefinition in scenario.objectives {
            guard let type = ObjectiveType(rawValue: objectiveDefinition.kind) else {
                errors.append(DataValidationError(message: "未知目标类型 \(objectiveDefinition.kind)。"))
                continue
            }
            objectives.append(
                Objective(
                    id: objectiveDefinition.id,
                    name: objectiveDefinition.name,
                    coord: HexCoord(q: objectiveDefinition.coord.q, r: objectiveDefinition.coord.r),
                    type: type
                )
            )
        }

        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }

        return MapState(
            width: scenario.map.width,
            height: scenario.map.height,
            tiles: tiles,
            supplySources: supplySources,
            objectives: objectives,
            featureMarkers: featureMarkers
        )
    }

    private func apply(_ regionData: RegionDataSet, to map: inout MapState) throws {
        map.regions = regionData.toRegions()
        map.hexToRegion = regionData.toHexToRegion()
        map.regionEdges = regionData.toRegionEdges()

        for (coord, regionId) in map.hexToRegion {
            guard var tile = map.tile(at: coord) else { continue }
            tile.regionId = regionId
            map.setTile(tile)
        }

        let errors = map.validateRegionGraph().map { DataValidationError(message: $0.description) }
        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }
    }

    private func assignGenerals(
        to deploymentState: WarDeploymentState,
        map: MapState,
        regionData: RegionDataSet,
        registry: GeneralRegistry? = nil
    ) -> WarDeploymentState {
        let registry = registry ?? (try? loadGeneralRegistry()) ?? .empty
        let seedAssignments = Dictionary(uniqueKeysWithValues: regionData.regions.compactMap { definition in
            definition.assignedGeneralId.map { (definition.id, $0) }
        })
        return GeneralDispatcher(registry: registry).assignGenerals(
            to: deploymentState,
            map: map,
            seedAssignments: seedAssignments
        )
    }

    private func makeDivisions(
        from definitions: [InitialUnitDefinition],
        templates: [UnitTemplateDefinition]? = nil
    ) throws -> [Division] {
        let templates = templates ?? ((try? loadUnitTemplates()) ?? [])
        var errors: [DataValidationError] = []
        let divisions = definitions.compactMap { definition -> Division? in
            guard let faction = Faction(rawValue: definition.faction) else {
                errors.append(DataValidationError(message: "军队 \(definition.id) 使用未知势力 \(definition.faction)。"))
                return nil
            }

            let components: [DivisionComponent]
            if let template = templates.first(where: { $0.id == definition.templateId }) {
                components = template.components.compactMap { component in
                    guard let type = ComponentType(rawValue: component.type) else { return nil }
                    return DivisionComponent(type: type, weight: component.weight)
                }
            } else {
                components = fallbackComponents(for: definition.templateId)
            }

            guard !components.isEmpty else {
                errors.append(DataValidationError(message: "军队 \(definition.id) 引用了未知模板 \(definition.templateId)。"))
                return nil
            }

            return Division(
                id: definition.id,
                name: definition.name,
                faction: faction,
                coord: HexCoord(q: definition.coord.q, r: definition.coord.r),
                facing: HexDirection(rawValue: definition.facing) ?? .west,
                hp: definition.hp,
                maxHP: 10,
                components: components,
                supplyState: SupplyState(rawValue: definition.supplyState) ?? .supplied,
                retreatMode: definition.retreatMode.flatMap(RetreatMode.init(rawValue:)) ?? .retreatable
            )
        }

        if !errors.isEmpty {
            throw DataLoaderError.validationFailed(errors)
        }
        return divisions
    }

    private func fallbackComponents(for templateId: String) -> [DivisionComponent] {
        switch templateId {
        case "tank_division", "panzer_division":
            return [DivisionComponent(type: .tank, weight: 0.7), DivisionComponent(type: .motorizedInfantry, weight: 0.3)]
        case "motorized_division":
            return [DivisionComponent(type: .motorizedInfantry, weight: 1.0)]
        case "artillery_division":
            return [DivisionComponent(type: .artillery, weight: 1.0)]
        case "suitang_cavalry_column":
            return [DivisionComponent(type: .cavalry, weight: 0.82), DivisionComponent(type: .infantry, weight: 0.18)]
        case "suitang_archer_camp":
            return [DivisionComponent(type: .archer, weight: 0.55), DivisionComponent(type: .infantry, weight: 0.45)]
        case "suitang_siege_train":
            return [DivisionComponent(type: .siegeEngine, weight: 0.65), DivisionComponent(type: .infantry, weight: 0.35)]
        case "suitang_garrison":
            return [DivisionComponent(type: .guard, weight: 0.50), DivisionComponent(type: .infantry, weight: 0.30), DivisionComponent(type: .archer, weight: 0.20)]
        case "suitang_frontier_raiders":
            return [DivisionComponent(type: .cavalry, weight: 0.86), DivisionComponent(type: .militia, weight: 0.14)]
        case "suitang_infantry_host":
            return [DivisionComponent(type: .infantry, weight: 0.78), DivisionComponent(type: .archer, weight: 0.12), DivisionComponent(type: .cavalry, weight: 0.10)]
        default:
            return [DivisionComponent(type: .infantry, weight: 1.0)]
        }
    }

    private func makeTheaterState(
        map: MapState,
        regionData: RegionDataSet,
        divisions: [Division],
        turn: Int
    ) -> TheaterState {
        let assignments = Dictionary(uniqueKeysWithValues: regionData.regions.compactMap { definition in
            definition.theaterId.map { (definition.id, $0) }
        })

        guard !assignments.isEmpty else {
            return TheaterSystem().makeInitialFixedTheaters(map: map, divisions: divisions, turn: turn)
        }

        var groupedRegions: [TheaterId: [RegionId]] = [:]
        for regionId in map.regions.keys {
            let theaterId = assignments[regionId] ?? TheaterId("unassigned")
            groupedRegions[theaterId, default: []].append(regionId)
        }

        let theaters = Dictionary(uniqueKeysWithValues: groupedRegions.map { theaterId, regionIds in
            let sortedRegionIds = regionIds.sorted { $0.rawValue < $1.rawValue }
            let controllingFaction = majorityController(regionIds: sortedRegionIds, map: map)
            return (
                theaterId,
                TheaterNode(
                    id: theaterId,
                    name: theaterId.rawValue,
                    status: .active,
                    regionIds: sortedRegionIds,
                    controllingFaction: controllingFaction
                )
            )
        })

        let regionToTheater = Dictionary(uniqueKeysWithValues: groupedRegions.flatMap { theaterId, regionIds in
            regionIds.map { ($0, theaterId) }
        })
        let state = TheaterState(theaters: theaters, regionToTheater: regionToTheater)
        var updated = TheaterSystem().updateTheaters(state: state, map: map, divisions: divisions, turn: turn)
        updated.initialSnapshot = TheaterInitialSnapshot.capture(from: updated)
        return updated
    }

    private func majorityController(regionIds: [RegionId], map: MapState) -> Faction? {
        let counts = Dictionary(grouping: regionIds.compactMap { map.regions[$0]?.controller }) { $0 }
            .mapValues(\.count)
        return counts.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key.rawValue < rhs.key.rawValue : lhs.value > rhs.value
        }.first?.key
    }

    private func resourceURL(named resourceName: String) throws -> URL {
        if let resourceDirectory {
            return resourceDirectory
                .appendingPathComponent(resourceName)
                .appendingPathExtension("json")
        }

        #if DEBUG
        if let sourceURL = sourceDataURL(named: resourceName) {
            return sourceURL
        }
        #endif

        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw DataLoaderError.missingResource(resourceName)
        }
        return url
    }

    #if DEBUG
    private func sourceDataURL(named resourceName: String) -> URL? {
        let fileURL = URL(fileURLWithPath: #filePath)
        let dataDirectory = fileURL.deletingLastPathComponent()
        let url = dataDirectory
            .appendingPathComponent(resourceName)
            .appendingPathExtension("json")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    #endif

    private func appendDuplicateErrors(
        _ values: [String],
        label: String,
        to errors: inout [DataValidationError]
    ) {
        var seen: Set<String> = []
        var duplicates: Set<String> = []

        for value in values where !seen.insert(value).inserted {
            duplicates.insert(value)
        }

        for duplicate in duplicates.sorted() {
            errors.append(DataValidationError(message: "\(label) 重复：\(duplicate)。"))
        }
    }
}
