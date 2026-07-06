import Foundation

enum MapEditorMode: String, Codable, CaseIterable, Identifiable {
    case hexPainter
    case regionBuilder
    case theaterAssignment
    case unitPlanner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hexPainter:
            return "地块"
        case .regionBuilder:
            return "州郡"
        case .theaterAssignment:
            return "方面"
        case .unitPlanner:
            return "军队"
        }
    }
}

enum MapEditorEditAction: String, Codable, CaseIterable, Identifiable {
    case idle
    case adding
    case deleting

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idle:
            return "未编辑"
        case .adding:
            return "添加"
        case .deleting:
            return "删除"
        }
    }
}

enum MapEditorHexTool: String, Codable, CaseIterable, Identifiable {
    case paint
    case extend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paint:
            return "覆盖"
        case .extend:
            return "扩展"
        }
    }
}

struct MapEditorHex: Codable, Equatable, Identifiable {
    var coord: HexCoord
    var terrain: BaseTerrain
    var hasRoad: Bool
    var controller: Faction?
    var cityName: String?
    var fortressName: String?
    var isSupplySource: Bool
    var supplyFaction: Faction?
    var objectiveId: String?
    var regionId: RegionId?

    var id: String { coord.mapEditorKey }

    init(
        coord: HexCoord,
        terrain: BaseTerrain = .plain,
        hasRoad: Bool = false,
        controller: Faction? = nil,
        cityName: String? = nil,
        fortressName: String? = nil,
        isSupplySource: Bool = false,
        supplyFaction: Faction? = nil,
        objectiveId: String? = nil,
        regionId: RegionId? = nil
    ) {
        self.coord = coord
        self.terrain = terrain
        self.hasRoad = hasRoad
        self.controller = controller
        self.cityName = cityName
        self.fortressName = fortressName
        self.isSupplySource = isSupplySource
        self.supplyFaction = supplyFaction
        self.objectiveId = objectiveId
        self.regionId = regionId
    }
}

struct MapEditorRegionDraft: Codable, Equatable, Identifiable {
    var id: RegionId
    var name: String
    var owner: Faction?
    var controller: Faction?
    var infrastructure: Int
    var supplyValue: Int
    var factories: Int
    var coreOf: [Faction]
    var assignedGeneralId: String?

    init(
        id: RegionId,
        name: String? = nil,
        owner: Faction? = nil,
        controller: Faction? = nil,
        infrastructure: Int = 0,
        supplyValue: Int = 0,
        factories: Int = 0,
        coreOf: [Faction] = [],
        assignedGeneralId: String? = nil
    ) {
        self.id = id
        self.name = name ?? "未命名州郡"
        self.owner = owner
        self.controller = controller
        self.infrastructure = infrastructure
        self.supplyValue = supplyValue
        self.factories = factories
        self.coreOf = coreOf
        self.assignedGeneralId = assignedGeneralId
    }
}

struct MapEditorTheaterDraft: Codable, Equatable, Identifiable {
    var id: TheaterId
    var name: String

    init(id: TheaterId, name: String? = nil) {
        self.id = id
        self.name = name ?? "未命名方面"
    }
}

struct MapEditorUnitDraft: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var faction: Faction
    var templateId: String
    var coord: HexCoord
    var facing: HexDirection
    var hp: Int
    var retreatMode: RetreatMode
    var supplyState: SupplyState
    var assignedAgentId: String?

    init(
        id: String,
        name: String,
        faction: Faction,
        templateId: String,
        coord: HexCoord,
        facing: HexDirection = .west,
        hp: Int = 10,
        retreatMode: RetreatMode = .retreatable,
        supplyState: SupplyState = .supplied,
        assignedAgentId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.faction = faction
        self.templateId = templateId
        self.coord = coord
        self.facing = facing
        self.hp = hp
        self.retreatMode = retreatMode
        self.supplyState = supplyState
        self.assignedAgentId = assignedAgentId
    }
}

struct MapEditorKeyLocationDraft: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var kind: String
    var coord: HexCoord
    var faction: Faction?
    var objectiveId: String?

    init(
        id: String,
        name: String,
        kind: String,
        coord: HexCoord,
        faction: Faction? = nil,
        objectiveId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.coord = coord
        self.faction = faction
        self.objectiveId = objectiveId
    }
}

struct MapEditorBackgroundImage: Codable, Equatable {
    var filePath: String
    var opacity: Double
    var scale: Double
    var positionX: Double
    var positionY: Double

    init(
        filePath: String,
        opacity: Double = 0.45,
        scale: Double = 1,
        positionX: Double = 0,
        positionY: Double = 0
    ) {
        self.filePath = filePath
        self.opacity = opacity
        self.scale = scale
        self.positionX = positionX
        self.positionY = positionY
    }
}

struct MapEditorDocument: Codable, Equatable, Identifiable {
    var id: String
    var displayName: String
    var width: Int
    var height: Int
    var hexes: [HexCoord: MapEditorHex]
    var regions: [RegionId: MapEditorRegionDraft]
    var theaters: [TheaterId: MapEditorTheaterDraft]
    var regionTheaterAssignments: [RegionId: TheaterId]
    var initialUnits: [MapEditorUnitDraft]
    var keyLocations: [MapEditorKeyLocationDraft]
    var keyLocationsAreAuthoritative: Bool
    var suppressedKeyLocationCoordKeys: Set<String>
    var backgroundImage: MapEditorBackgroundImage?

    init(
        id: String,
        displayName: String,
        width: Int,
        height: Int,
        hexes: [HexCoord: MapEditorHex],
        regions: [RegionId: MapEditorRegionDraft] = [:],
        theaters: [TheaterId: MapEditorTheaterDraft] = [:],
        regionTheaterAssignments: [RegionId: TheaterId] = [:],
        initialUnits: [MapEditorUnitDraft] = [],
        keyLocations: [MapEditorKeyLocationDraft] = [],
        keyLocationsAreAuthoritative: Bool = true,
        suppressedKeyLocationCoordKeys: Set<String> = [],
        backgroundImage: MapEditorBackgroundImage? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.width = width
        self.height = height
        self.hexes = hexes
        self.regions = regions
        self.theaters = theaters
        self.regionTheaterAssignments = regionTheaterAssignments
        self.initialUnits = initialUnits
        self.keyLocations = keyLocations
        self.keyLocationsAreAuthoritative = keyLocationsAreAuthoritative
        self.suppressedKeyLocationCoordKeys = suppressedKeyLocationCoordKeys
        self.backgroundImage = backgroundImage
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case width
        case height
        case hexes
        case regions
        case theaters
        case regionTheaterAssignments
        case initialUnits
        case keyLocations
        case keyLocationsAreAuthoritative
        case suppressedKeyLocationCoordKeys
        case backgroundImage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        width = try container.decode(Int.self, forKey: .width)
        height = try container.decode(Int.self, forKey: .height)
        hexes = try container.decode([HexCoord: MapEditorHex].self, forKey: .hexes)
        regions = try container.decode([RegionId: MapEditorRegionDraft].self, forKey: .regions)
        theaters = try container.decode([TheaterId: MapEditorTheaterDraft].self, forKey: .theaters)
        regionTheaterAssignments = try container.decode([RegionId: TheaterId].self, forKey: .regionTheaterAssignments)
        initialUnits = try container.decode([MapEditorUnitDraft].self, forKey: .initialUnits)
        keyLocations = try container.decodeIfPresent([MapEditorKeyLocationDraft].self, forKey: .keyLocations) ?? []
        keyLocationsAreAuthoritative = try container.decodeIfPresent(
            Bool.self,
            forKey: .keyLocationsAreAuthoritative
        ) ?? false
        suppressedKeyLocationCoordKeys = Set(
            try container.decodeIfPresent([String].self, forKey: .suppressedKeyLocationCoordKeys) ?? []
        )
        backgroundImage = try container.decodeIfPresent(MapEditorBackgroundImage.self, forKey: .backgroundImage)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(hexes, forKey: .hexes)
        try container.encode(regions, forKey: .regions)
        try container.encode(theaters, forKey: .theaters)
        try container.encode(regionTheaterAssignments, forKey: .regionTheaterAssignments)
        try container.encode(initialUnits, forKey: .initialUnits)
        try container.encode(keyLocations, forKey: .keyLocations)
        try container.encode(keyLocationsAreAuthoritative, forKey: .keyLocationsAreAuthoritative)
        try container.encode(suppressedKeyLocationCoordKeys.sorted(), forKey: .suppressedKeyLocationCoordKeys)
        try container.encodeIfPresent(backgroundImage, forKey: .backgroundImage)
    }

    static func new(id: String = "mapeditor_suitang_scenario", displayName: String = "隋唐地图草稿", width: Int, height: Int) -> MapEditorDocument {
        var hexes: [HexCoord: MapEditorHex] = [:]
        for q in 0..<max(1, width) {
            for r in 0..<max(1, height) {
                let coord = HexCoord(q: q, r: r)
                hexes[coord] = MapEditorHex(coord: coord)
            }
        }
        return MapEditorDocument(
            id: id,
            displayName: displayName,
            width: max(1, width),
            height: max(1, height),
            hexes: hexes
        )
    }

    var sortedHexes: [MapEditorHex] {
        hexes.values.sorted { lhs, rhs in
            lhs.coord.r == rhs.coord.r ? lhs.coord.q < rhs.coord.q : lhs.coord.r < rhs.coord.r
        }
    }

    var isSparse: Bool {
        hexes.count != width * height
    }

    mutating func resize(width newWidth: Int, height newHeight: Int) {
        let clampedWidth = max(1, newWidth)
        let clampedHeight = max(1, newHeight)
        var next: [HexCoord: MapEditorHex] = [:]

        for q in 0..<clampedWidth {
            for r in 0..<clampedHeight {
                let coord = HexCoord(q: q, r: r)
                next[coord] = hexes[coord] ?? MapEditorHex(coord: coord)
            }
        }

        let validRegions = Set(next.values.compactMap(\.regionId))
        regions = regions.filter { validRegions.contains($0.key) }
        regionTheaterAssignments = regionTheaterAssignments.filter { validRegions.contains($0.key) }
        initialUnits.removeAll { next[$0.coord] == nil }
        keyLocations.removeAll { next[$0.coord] == nil }
        suppressedKeyLocationCoordKeys = suppressedKeyLocationCoordKeys.filter { key in
            guard let coord = HexCoord(mapEditorKey: key) else { return false }
            return next[coord] != nil
        }
        width = clampedWidth
        height = clampedHeight
        hexes = next
    }

    mutating func setHex(_ hex: MapEditorHex) {
        guard contains(hex.coord) else { return }
        hexes[hex.coord] = hex
    }

    @discardableResult
    mutating func addHex(at coord: HexCoord, terrain: BaseTerrain = .plain) -> Bool {
        guard !contains(coord) else { return false }
        guard hexes.isEmpty || coord.neighbors.contains(where: { hexes[$0] != nil }) else {
            return false
        }
        hexes[coord] = MapEditorHex(coord: coord, terrain: terrain)
        updateBoundsToFitHexes()
        return true
    }

    mutating func deleteHex(at coord: HexCoord) {
        guard contains(coord) else { return }
        let removedRegionId = hexes[coord]?.regionId
        hexes.removeValue(forKey: coord)
        initialUnits.removeAll { $0.coord == coord }
        removeKeyLocation(at: coord)

        if let removedRegionId,
           !hexes.values.contains(where: { $0.regionId == removedRegionId }) {
            regions.removeValue(forKey: removedRegionId)
            regionTheaterAssignments.removeValue(forKey: removedRegionId)
        }

        let validRegions = Set(hexes.values.compactMap(\.regionId))
        regionTheaterAssignments = regionTheaterAssignments.filter { validRegions.contains($0.key) }
        updateBoundsToFitHexes()
    }

    mutating func resetHex(at coord: HexCoord) {
        guard contains(coord) else { return }
        hexes[coord] = MapEditorHex(coord: coord)
        initialUnits.removeAll { $0.coord == coord }
        removeKeyLocation(at: coord)
    }

    mutating func createRegion(id: RegionId, name: String? = nil, controller: Faction? = nil) {
        regions[id] = MapEditorRegionDraft(id: id, name: name, controller: controller)
    }

    mutating func createTheater(id: TheaterId, name: String? = nil) {
        theaters[id] = MapEditorTheaterDraft(id: id, name: name)
    }

    mutating func assign(_ coord: HexCoord, to regionId: RegionId?) {
        guard contains(coord), var hex = hexes[coord] else { return }
        hex.regionId = regionId
        hexes[coord] = hex
    }

    mutating func assign(regionId: RegionId, to theaterId: TheaterId?) {
        if let theaterId {
            regionTheaterAssignments[regionId] = theaterId
        } else {
            regionTheaterAssignments.removeValue(forKey: regionId)
        }
    }

    func keyLocation(at coord: HexCoord) -> MapEditorKeyLocationDraft? {
        keyLocations.first { $0.coord == coord }
    }

    mutating func upsertKeyLocation(_ location: MapEditorKeyLocationDraft) {
        guard contains(location.coord) else { return }
        if let index = keyLocations.firstIndex(where: { $0.coord == location.coord }) {
            keyLocations[index] = location
        } else {
            keyLocations.append(location)
        }
        suppressedKeyLocationCoordKeys.remove(location.coord.mapEditorKey)
    }

    mutating func removeKeyLocation(at coord: HexCoord) {
        keyLocations.removeAll { $0.coord == coord }
        suppressedKeyLocationCoordKeys.insert(coord.mapEditorKey)
    }

    func isKeyLocationSuppressed(at coord: HexCoord) -> Bool {
        suppressedKeyLocationCoordKeys.contains(coord.mapEditorKey)
    }

    func contains(_ coord: HexCoord) -> Bool {
        hexes[coord] != nil
    }

    private mutating func updateBoundsToFitHexes() {
        guard !hexes.isEmpty else {
            width = 1
            height = 1
            return
        }

        let qValues = hexes.keys.map(\.q)
        let rValues = hexes.keys.map(\.r)
        let minQ = qValues.min() ?? 0
        let maxQ = qValues.max() ?? 0
        let minR = rValues.min() ?? 0
        let maxR = rValues.max() ?? 0
        width = max(1, maxQ - minQ + 1)
        height = max(1, maxR - minR + 1)
    }
}

enum MapEditorStorage {
    static func save(_ document: MapEditorDocument, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(document).write(to: url, options: .atomic)
    }

    static func load(from url: URL) throws -> MapEditorDocument {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(MapEditorDocument.self, from: data)
    }
}

extension HexCoord {
    init?(mapEditorKey: String) {
        let parts = mapEditorKey.split(separator: ",").map(String.init)
        guard parts.count == 2,
              let q = Int(parts[0]),
              let r = Int(parts[1]) else {
            return nil
        }
        self.init(q: q, r: r)
    }

    var mapEditorKey: String {
        "\(q),\(r)"
    }
}
