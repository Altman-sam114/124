import Foundation
import Combine

final class MapEditorViewModel: ObservableObject {
    @Published var document: MapEditorDocument
    @Published var mode: MapEditorMode = .hexPainter
    @Published var editAction: MapEditorEditAction = .idle
    @Published var hexTool: MapEditorHexTool = .paint
    @Published var selectedTerrain: BaseTerrain = .plain
    @Published var paintRoad: Bool = false
    @Published var paintController: Faction? = nil
    @Published var paintSupply: Bool = false
    @Published var supplyFaction: Faction = .tang
    @Published var selectedRegionId: RegionId?
    @Published var selectedTheaterId: TheaterId?
    @Published var eraseRegionMembership: Bool = false
    @Published var selectedUnitTemplateId: String = "suitang_infantry_host"
    @Published var selectedUnitFaction: Faction = .tang
    @Published var selectedUnitHP: Int = 10
    @Published var selectedUnitFacing: HexDirection = .west
    @Published var eraseUnits: Bool = false
    @Published var pendingRegionHexes: Set<HexCoord> = []
    @Published var pendingTheaterRegions: Set<RegionId> = []
    @Published var pendingUnitHexes: Set<HexCoord> = []
    @Published var redrawToken: Int = 0
    @Published var lastExportResult: MapEditorExportResult?
    @Published var lastErrorMessage: String?
    @Published var lastStatusMessage: String?
    @Published var inspectedCoord: HexCoord?
    @Published var inspectedRegionName: String = ""
    @Published var inspectedTheaterName: String = ""
    @Published var inspectedKeyLocationName: String = ""
    @Published var inspectedKeyLocationKind: String = "ferry"
    @Published var inspectedKeyLocationFaction: Faction?
    @Published var inspectedKeyLocationObjectiveId: String = ""
    @Published var backgroundOpacity: Double = 0.45
    @Published var backgroundScale: Double = 1
    @Published var backgroundOffsetX: Double = 0
    @Published var backgroundOffsetY: Double = 0

    @Published var newRegionText: String = "新州郡"
    @Published var newTheaterText: String = "新方面"
    @Published var newUnitNameText: String = "军队"

    init(document: MapEditorDocument = .new(width: 8, height: 6)) {
        self.document = document
    }

    var keyLocationKindOptions: [String] {
        var options = ["capital", "city", "fortress", "pass", "granary", "supply", "ferry", "port", "harbor"]
        if !inspectedKeyLocationKind.isEmpty, !options.contains(inspectedKeyLocationKind) {
            options.append(inspectedKeyLocationKind)
        }
        return options
    }

    var inspectedKeyLocationExists: Bool {
        guard let inspectedCoord else { return false }
        return document.keyLocation(at: inspectedCoord) != nil
    }

    func newMap(width: Int, height: Int) {
        document = .new(width: width, height: height)
        selectedRegionId = nil
        selectedTheaterId = nil
        clearInspection()
        clearPendingSelection()
        markChanged()
    }

    func resize(width: Int, height: Int) {
        document.resize(width: width, height: height)
        if let inspectedCoord, !document.contains(inspectedCoord) {
            clearInspection()
        }
        markChanged()
    }

    func createRegion(idText: String? = nil) {
        let id: RegionId
        let name: String
        if let idText {
            let raw = idText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return }
            id = RegionId(raw)
            name = raw
        } else {
            let nextIndex = nextRegionIndex()
            id = RegionId("region_\(nextIndex)")
            let rawName = newRegionText.trimmingCharacters(in: .whitespacesAndNewlines)
            name = rawName.isEmpty ? "州郡 \(nextIndex)" : rawName
        }
        document.createRegion(id: id, name: name)
        selectedRegionId = id
        lastStatusMessage = "已创建州郡：\(displayMapEditorName(name, fallback: "州郡"))。"
        markChanged()
    }

    func createTheater(idText: String? = nil) {
        let id: TheaterId
        let name: String
        if let idText {
            let raw = idText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return }
            id = TheaterId(raw)
            name = raw
        } else {
            let nextIndex = nextTheaterIndex()
            id = TheaterId("theater_\(nextIndex)")
            let rawName = newTheaterText.trimmingCharacters(in: .whitespacesAndNewlines)
            name = rawName.isEmpty ? "方面 \(nextIndex)" : rawName
        }
        document.createTheater(id: id, name: name)
        selectedTheaterId = id
        lastStatusMessage = "已创建方面：\(displayMapEditorName(name, fallback: "方面"))。"
        markChanged()
    }

    func prepareNewRegion() {
        selectedRegionId = nil
        pendingRegionHexes.removeAll()
        lastStatusMessage = "将自动生成新的州郡。"
        markChanged()
    }

    func prepareNewTheater() {
        selectedTheaterId = nil
        pendingTheaterRegions.removeAll()
        lastStatusMessage = "将自动生成新的方面。"
        markChanged()
    }

    func beginAdding() {
        if mode == .hexPainter {
            hexTool = .paint
        }
        editAction = .adding
        clearPendingSelection()
        ensureDraftExistsForCurrentMode()
        lastStatusMessage = "\(mode.title)添加中：在右侧地图点击或拖拽。"
        markChanged()
    }

    func beginExtendingHexes() {
        mode = .hexPainter
        hexTool = .extend
        editAction = .adding
        clearPendingSelection()
        lastStatusMessage = "扩展地块中：点击现有地块旁边的空位，默认生成平原。"
        markChanged()
    }

    func beginPaintingRiverEdges() {
        mode = .hexPainter
        hexTool = .riverEdge
        editAction = .adding
        clearPendingSelection()
        lastStatusMessage = "绘制河边中：点击地块边缘添加河边。"
        markChanged()
    }

    func beginErasingRiverEdges() {
        mode = .hexPainter
        hexTool = .riverEdge
        editAction = .deleting
        clearPendingSelection()
        lastStatusMessage = "擦除河边中：点击已有河边的边缘。"
        markChanged()
    }

    func beginDeleting() {
        if mode == .hexPainter {
            hexTool = .paint
        }
        editAction = .deleting
        clearPendingSelection()
        lastStatusMessage = "\(mode.title)删除中：在右侧地图点击或拖拽。"
        markChanged()
    }

    func finishEditing() {
        switch mode {
        case .hexPainter:
            break
        case .regionBuilder:
            commitPendingRegion()
        case .theaterAssignment:
            commitPendingTheater()
        case .unitPlanner:
            commitPendingUnits()
        }
        hexTool = .paint
        editAction = .idle
        clearPendingSelection()
        lastStatusMessage = "\(mode.title)编辑已完成。"
        markChanged()
    }

    func cancelEditing() {
        hexTool = .paint
        editAction = .idle
        clearPendingSelection()
        lastStatusMessage = "已取消编辑。"
        markChanged()
    }

    func applyPrimaryAction(at coord: HexCoord) {
        guard editAction != .idle else { return }
        guard mode == .hexPainter || document.contains(coord) else { return }
        switch mode {
        case .hexPainter:
            editHex(at: coord)
        case .regionBuilder:
            stageRegionMembership(at: coord)
        case .theaterAssignment:
            stageTheaterAssignment(at: coord)
        case .unitPlanner:
            stageInitialUnit(at: coord)
        }
        markChanged()
    }

    func applyRiverEdgeAction(at coord: HexCoord, direction: HexDirection) {
        guard mode == .hexPainter,
              hexTool == .riverEdge,
              editAction != .idle,
              var hex = document.hexes[coord] else {
            return
        }

        switch editAction {
        case .adding:
            hex.riverEdges.insert(direction)
            lastStatusMessage = "已添加\(direction.displayName)向河边。"
        case .deleting:
            hex.riverEdges.remove(direction)
            lastStatusMessage = "已擦除\(direction.displayName)向河边。"
        case .idle:
            return
        }
        document.setHex(hex)
        markChanged()
    }

    func handleShortcut(_ key: String) -> Bool {
        switch key.lowercased() {
        case "n":
            beginAdding()
            return true
        case "m":
            finishEditing()
            return true
        default:
            return false
        }
    }

    func inspect(at coord: HexCoord) {
        inspectedCoord = coord
        guard let hex = document.hexes[coord] else {
            clearInspectedTextFields()
            lastStatusMessage = "所选位置没有地块。"
            markChanged()
            return
        }

        if let regionId = hex.regionId, let region = document.regions[regionId] {
            inspectedRegionName = region.name
            if let theaterId = document.regionTheaterAssignments[regionId],
               let theater = document.theaters[theaterId] {
                inspectedTheaterName = theater.name
            } else {
                inspectedTheaterName = ""
            }
        } else {
            inspectedRegionName = ""
            inspectedTheaterName = ""
        }
        syncInspectedKeyLocationFields(coord: coord, hex: hex)
        lastStatusMessage = "已选中地图位置：\(displayPosition(for: coord))。"
        markChanged()
    }

    func saveInspectedInfo() {
        guard let inspectedCoord,
              let hex = document.hexes[inspectedCoord],
              let regionId = hex.regionId else {
            lastStatusMessage = "当前选中地块没有州郡信息可保存。"
            markChanged()
            return
        }

        let regionName = inspectedRegionName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !regionName.isEmpty, var region = document.regions[regionId] {
            region.name = regionName
            document.regions[regionId] = region
        }

        let theaterName = inspectedTheaterName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !theaterName.isEmpty,
           let theaterId = document.regionTheaterAssignments[regionId],
           var theater = document.theaters[theaterId] {
            theater.name = theaterName
            document.theaters[theaterId] = theater
        }

        lastStatusMessage = "已保存选中信息。"
        markChanged()
    }

    func saveInspectedKeyLocation() {
        guard let inspectedCoord,
              let hex = document.hexes[inspectedCoord] else {
            lastStatusMessage = "当前没有可保存地点的选中地块。"
            markChanged()
            return
        }

        let name = inspectedKeyLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind = inspectedKeyLocationKind.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !kind.isEmpty else {
            lastStatusMessage = "地点名称和类型不能为空。"
            markChanged()
            return
        }

        let objectiveId = inspectedKeyLocationObjectiveId.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = document.keyLocation(at: inspectedCoord)
        let location = MapEditorKeyLocationDraft(
            id: existing?.id ?? keyLocationId(kind: kind, coord: inspectedCoord),
            name: name,
            kind: kind,
            coord: inspectedCoord,
            faction: inspectedKeyLocationFaction,
            objectiveId: objectiveId.isEmpty ? nil : objectiveId
        )
        document.upsertKeyLocation(location)
        lastStatusMessage = "已保存地点：\(displayMapEditorName(name, fallback: "地点"))。"
        markChanged()
    }

    func deleteInspectedKeyLocation() {
        guard let inspectedCoord,
              let hex = document.hexes[inspectedCoord] else {
            lastStatusMessage = "当前没有可删除地点的选中地块。"
            markChanged()
            return
        }

        if let location = document.keyLocation(at: inspectedCoord) {
            document.removeKeyLocation(at: inspectedCoord)
            syncInspectedKeyLocationFields(coord: inspectedCoord, hex: hex)
            lastStatusMessage = "已删除地点：\(displayMapEditorName(location.name, fallback: "地点"))。"
        } else if hasDerivedKeyLocation(for: hex) {
            document.removeKeyLocation(at: inspectedCoord)
            syncInspectedKeyLocationFields(coord: inspectedCoord, hex: hex)
            lastStatusMessage = "已禁止导出该地块的派生地点。"
        } else {
            lastStatusMessage = "当前地块没有独立地点记录。"
        }
        markChanged()
    }

    func setBackgroundImage(path: String) {
        document.backgroundImage = MapEditorBackgroundImage(
            filePath: path,
            opacity: backgroundOpacity,
            scale: backgroundScale,
            positionX: backgroundOffsetX,
            positionY: backgroundOffsetY
        )
        lastStatusMessage = "已导入底图。"
        markChanged()
    }

    func clearBackgroundImage() {
        document.backgroundImage = nil
        lastStatusMessage = "已移除底图。"
        markChanged()
    }

    func updateBackgroundImageSettings() {
        guard var backgroundImage = document.backgroundImage else { return }
        backgroundImage.opacity = max(0, min(1, backgroundOpacity))
        backgroundImage.scale = max(0.05, min(20, backgroundScale))
        backgroundImage.positionX = backgroundOffsetX
        backgroundImage.positionY = backgroundOffsetY
        document.backgroundImage = backgroundImage
        markChanged()
    }

    func moveBackgroundBy(deltaX: Double, deltaY: Double) {
        backgroundOffsetX += deltaX
        backgroundOffsetY += deltaY
        updateBackgroundImageSettings()
    }

    func saveDocument(to url: URL) {
        do {
            try MapEditorStorage.save(document, to: url)
            lastErrorMessage = nil
            lastStatusMessage = "地图草稿已保存。"
        } catch {
            lastErrorMessage = displayMessage(for: error)
        }
    }

    func loadDocument(from url: URL) {
        do {
            document = try MapEditorStorage.load(from: url)
            clearInspection()
            syncBackgroundControlsFromDocument()
            lastErrorMessage = nil
            lastStatusMessage = "地图草稿已读取。"
            markChanged()
        } catch {
            lastErrorMessage = displayMessage(for: error)
        }
    }

    func loadDefaultGameResources() {
        do {
            let importResult = try MapEditorGameResourceBridge.loadDefaultDocumentResult()
            document = importResult.document
            selectedRegionId = document.regions.keys.sorted { $0.rawValue < $1.rawValue }.first
            selectedTheaterId = document.theaters.keys.sorted { $0.rawValue < $1.rawValue }.first
            clearInspection()
            syncBackgroundControlsFromDocument()
            lastErrorMessage = nil
            lastStatusMessage = importResult.statusMessage(successMessage: "已读取默认隋唐游戏资源。")
            markChanged()
        } catch {
            lastErrorMessage = displayMessage(for: error)
        }
    }

    func overwriteDefaultGameResources() {
        do {
            let result = try MapEditorGameResourceBridge.overwriteDefaultGameResources(document: document)
            lastExportResult = result
            lastErrorMessage = nil
            lastStatusMessage = "已覆盖默认隋唐战局资源。"
        } catch {
            lastErrorMessage = displayMessage(for: error)
        }
    }

    @discardableResult
    func export() -> MapEditorExportResult? {
        do {
            let result = try MapEditorExporter.export(
                document: document,
                metadata: MapEditorGameResourceBridge.exportMetadata(for: document)
            )
            lastExportResult = result
            lastErrorMessage = nil
            lastStatusMessage = "战役资料预览已生成。"
            return result
        } catch {
            lastErrorMessage = displayMessage(for: error)
            return nil
        }
    }

    @discardableResult
    func export(to directory: URL) -> MapEditorExportResult? {
        guard let result = export() else { return nil }
        do {
            try MapEditorExporter.write(result, to: directory)
            lastErrorMessage = nil
            lastStatusMessage = "战役资料已导出。"
            return result
        } catch {
            lastErrorMessage = displayMessage(for: error)
            return nil
        }
    }

    func displayName(for regionId: RegionId) -> String {
        displayMapEditorName(document.regions[regionId]?.name, fallback: "未命名州郡")
    }

    func displayName(for theaterId: TheaterId) -> String {
        displayMapEditorName(document.theaters[theaterId]?.name, fallback: "未命名方面")
    }

    func displayPosition(for coord: HexCoord) -> String {
        "第 \(coord.q) 列，第 \(coord.r) 行"
    }

    private func editHex(at coord: HexCoord) {
        if editAction == .deleting {
            document.deleteHex(at: coord)
            return
        }
        if hexTool == .extend {
            if document.addHex(at: coord, terrain: .plain) {
                lastStatusMessage = "已扩展一处地块。"
            } else if !document.contains(coord) {
                lastStatusMessage = "扩展失败：新地块必须贴着已有地块。"
            }
            return
        }
        guard var hex = document.hexes[coord] else { return }
        hex.terrain = selectedTerrain
        hex.hasRoad = paintRoad
        hex.controller = paintController
        hex.isSupplySource = paintSupply
        hex.supplyFaction = paintSupply ? supplyFaction : nil
        if selectedTerrain == .city, hex.cityName == nil {
            hex.cityName = "未命名城池"
            hex.fortressName = nil
        } else if selectedTerrain == .fortress, hex.fortressName == nil {
            hex.fortressName = "未命名关隘"
            hex.cityName = nil
        } else if selectedTerrain != .city {
            hex.cityName = nil
        }
        if selectedTerrain != .fortress {
            hex.fortressName = nil
        }
        document.setHex(hex)
    }

    private func stageRegionMembership(at coord: HexCoord) {
        if editAction == .deleting || eraseRegionMembership {
            document.assign(coord, to: nil)
            return
        }
        pendingRegionHexes.insert(coord)
    }

    private func stageTheaterAssignment(at coord: HexCoord) {
        guard let regionId = document.hexes[coord]?.regionId else {
            return
        }
        if editAction == .deleting {
            document.assign(regionId: regionId, to: nil)
            return
        }
        pendingTheaterRegions.insert(regionId)
    }

    private func stageInitialUnit(at coord: HexCoord) {
        if editAction == .deleting || eraseUnits {
            document.initialUnits.removeAll { $0.coord == coord }
            return
        }
        pendingUnitHexes.insert(coord)
    }

    private func commitPendingRegion() {
        ensureDraftExistsForCurrentMode()
        guard let selectedRegionId else { return }
        for coord in pendingRegionHexes {
            document.assign(coord, to: selectedRegionId)
        }
    }

    private func commitPendingTheater() {
        ensureDraftExistsForCurrentMode()
        guard let selectedTheaterId else { return }
        for regionId in pendingTheaterRegions {
            document.assign(regionId: regionId, to: selectedTheaterId)
        }
    }

    private func commitPendingUnits() {
        for coord in pendingUnitHexes.sortedByMapOrder() {
            stampUnit(at: coord)
        }
    }

    private func stampUnit(at coord: HexCoord) {
        document.initialUnits.removeAll { $0.coord == coord }
        let nextIndex = document.initialUnits.count + 1
        let factionPrefix = selectedUnitFaction.mapEditorUnitPrefix
        let id = "\(factionPrefix)_editor_\(nextIndex)"
        document.initialUnits.append(
            MapEditorUnitDraft(
                id: id,
                name: "\(newUnitNameText) \(nextIndex)",
                faction: selectedUnitFaction,
                templateId: selectedUnitTemplateId,
                coord: coord,
                facing: selectedUnitFacing,
                hp: selectedUnitHP
            )
        )
    }

    private func ensureDraftExistsForCurrentMode() {
        switch mode {
        case .hexPainter, .unitPlanner:
            break
        case .regionBuilder:
            if selectedRegionId == nil {
                createRegion()
            }
        case .theaterAssignment:
            if selectedTheaterId == nil {
                createTheater()
            }
        }
    }

    private func clearPendingSelection() {
        pendingRegionHexes.removeAll()
        pendingTheaterRegions.removeAll()
        pendingUnitHexes.removeAll()
    }

    private func clearInspection() {
        inspectedCoord = nil
        clearInspectedTextFields()
    }

    private func clearInspectedTextFields() {
        inspectedRegionName = ""
        inspectedTheaterName = ""
        inspectedKeyLocationName = ""
        inspectedKeyLocationKind = "ferry"
        inspectedKeyLocationFaction = nil
        inspectedKeyLocationObjectiveId = ""
    }

    private func syncInspectedKeyLocationFields(coord: HexCoord, hex: MapEditorHex) {
        if let location = document.keyLocation(at: coord) {
            inspectedKeyLocationName = location.name
            inspectedKeyLocationKind = location.kind
            inspectedKeyLocationFaction = location.faction
            inspectedKeyLocationObjectiveId = location.objectiveId ?? ""
            return
        }

        if document.isKeyLocationSuppressed(at: coord) {
            inspectedKeyLocationName = ""
            inspectedKeyLocationKind = defaultKeyLocationKind(for: hex)
            inspectedKeyLocationFaction = nil
            inspectedKeyLocationObjectiveId = ""
            return
        }

        inspectedKeyLocationName = defaultKeyLocationName(for: hex)
        inspectedKeyLocationKind = defaultKeyLocationKind(for: hex)
        inspectedKeyLocationFaction = hex.supplyFaction ?? hex.controller
        inspectedKeyLocationObjectiveId = hex.objectiveId ?? ""
    }

    private func hasDerivedKeyLocation(for hex: MapEditorHex) -> Bool {
        hex.cityName != nil || hex.fortressName != nil || hex.isSupplySource
    }

    private func defaultKeyLocationName(for hex: MapEditorHex) -> String {
        if let cityName = hex.cityName {
            return cityName
        }
        if let fortressName = hex.fortressName {
            return fortressName
        }
        if hex.isSupplySource {
            return "未命名粮仓"
        }
        return ""
    }

    private func defaultKeyLocationKind(for hex: MapEditorHex) -> String {
        if hex.isSupplySource {
            return "granary"
        }
        if hex.terrain == .fortress {
            return "fortress"
        }
        if hex.terrain == .city {
            return "city"
        }
        return "ferry"
    }

    private func keyLocationId(kind: String, coord: HexCoord) -> String {
        let safeKind = kind
            .lowercased()
            .map { character -> Character in
                character.isLetter || character.isNumber ? character : "_"
            }
        let kindPart = String(safeKind).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return "loc_\(kindPart.isEmpty ? "site" : kindPart)_\(coord.q)_\(coord.r)"
    }

    private func markChanged() {
        redrawToken += 1
    }

    private func displayMessage(for error: Error) -> String {
        switch error {
        case let exportError as MapEditorExportError:
            return exportError.description
        case let bridgeError as MapEditorGameResourceBridgeError:
            return bridgeError.description
        default:
            return "地图工具操作失败，请检查当前文档和资源文件。"
        }
    }

    private func displayMapEditorName(_ name: String?, fallback: String) -> String {
        guard let name else {
            return fallback
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallback
        }

        let sanitized = sanitizeRawMapEditorIdentifier(in: trimmed)
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
            .replacingOccurrences(of: "德军", with: "旧剧本")
            .replacingOccurrences(of: "盟军", with: "旧剧本")
            .replacingOccurrences(of: "战区", with: "方面")

        return sanitized.isEmpty ? fallback : sanitized
    }

    private func sanitizeRawMapEditorIdentifier(in name: String) -> String {
        name
            .replacingOccurrences(
                of: #"\bregion_[A-Za-z0-9_\-]+\b"#,
                with: "相关州郡",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\btheater_[A-Za-z0-9_\-]+\b"#,
                with: "相关方面",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(front_zone|objective|obj|hex|loc)_[A-Za-z0-9_\-]+\b"#,
                with: "相关地点",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(division|unit)_[A-Za-z0-9_\-]+\b"#,
                with: "相关军队",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(germany|france|allied|axis|ger|all)_[A-Za-z0-9_\-]+\b"#,
                with: "相关旧战局",
                options: .regularExpression
            )
    }

    private func syncBackgroundControlsFromDocument() {
        guard let backgroundImage = document.backgroundImage else {
            backgroundOpacity = 0.45
            backgroundScale = 1
            backgroundOffsetX = 0
            backgroundOffsetY = 0
            return
        }
        backgroundOpacity = backgroundImage.opacity
        backgroundScale = backgroundImage.scale
        backgroundOffsetX = backgroundImage.positionX
        backgroundOffsetY = backgroundImage.positionY
    }

    private func nextRegionIndex() -> Int {
        nextNumericSuffix(
            used: document.regions.keys.map(\.rawValue),
            prefix: "region_"
        )
    }

    private func nextTheaterIndex() -> Int {
        nextNumericSuffix(
            used: document.theaters.keys.map(\.rawValue),
            prefix: "theater_"
        )
    }

    private func nextNumericSuffix(used: [String], prefix: String) -> Int {
        let usedIndices = Set(used.compactMap { raw -> Int? in
            guard raw.hasPrefix(prefix) else { return nil }
            return Int(raw.dropFirst(prefix.count))
        })
        var candidate = 1
        while usedIndices.contains(candidate) {
            candidate += 1
        }
        return candidate
    }
}

private extension Set where Element == HexCoord {
    func sortedByMapOrder() -> [HexCoord] {
        sorted { lhs, rhs in
            lhs.r == rhs.r ? lhs.q < rhs.q : lhs.r < rhs.r
        }
    }
}

private extension Faction {
    var mapEditorUnitPrefix: String {
        switch self {
        case .germany:
            return "legacy_germany"
        case .allies:
            return "legacy_allies"
        case .tang:
            return "tang"
        case .luoyangSui:
            return "luoyang_sui"
        case .wagang:
            return "wagang"
        case .xia:
            return "xia"
        case .qinXue:
            return "qin_xue"
        case .liuWuzhou:
            return "liu_wuzhou"
        case .tujue:
            return "tujue"
        }
    }
}
