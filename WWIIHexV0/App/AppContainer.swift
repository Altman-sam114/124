import Combine
import Foundation

struct SubmissionPresenceSummary: Identifiable, Equatable {
    let faction: Faction
    let activeDivisionCount: Int
    let controlledPassableHexCount: Int

    var id: String {
        faction.rawValue
    }

    var hasRuntimePresence: Bool {
        activeDivisionCount > 0 || controlledPassableHexCount > 0
    }

    var presenceText: String {
        "存活军队 \(activeDivisionCount)，受控可通行地块 \(controlledPassableHexCount)"
    }

    var turnOrderText: String {
        hasRuntimePresence ? "仍有实体存在，继续进入回合轮转" : "无实体存在，会退出通用回合轮转"
    }
}

final class AppContainer: ObservableObject {
    @Published private(set) var gameState: GameState
    @Published private(set) var selectedUnitId: String?
    @Published private(set) var selectedHex: HexCoord?
    @Published private(set) var selectedRegionId: RegionId?
    @Published private(set) var movementHighlights: Set<HexCoord>
    @Published private(set) var attackHighlights: Set<HexCoord>
    @Published private(set) var interactionLog: [GameLogEntry]
    @Published private(set) var lastCommandMessage: String?
    @Published private(set) var lastAgentDecisionRecord: AgentDecisionRecord?
    @Published private(set) var lastWarDirectiveRecords: [WarDirectiveRecord]
    @Published private(set) var observerModeEnabled: Bool
    @Published private(set) var mapDisplayLayer: MapDisplayLayer
    @Published private(set) var hasSavedGame: Bool
    @Published private(set) var saveStatus: GameSaveStatus?

    let commandHandler: GameCommandHandling
    let dataLoader: DataLoader
    let generalRegistry: GeneralRegistry
    var playerFaction: Faction {
        gameState.playerFaction
    }
    let warPipelineMode: WarPipelineMode
    let turnManager: TurnManager?
    private let saveStore: GameSaveStore
    private var isRunningAI = false

    init(
        gameState: GameState,
        commandHandler: GameCommandHandling,
        dataLoader: DataLoader,
        generalRegistry: GeneralRegistry = .empty,
        playerFaction: Faction? = nil,
        turnManager: TurnManager? = nil,
        warPipelineMode: WarPipelineMode = .marshalDirective,
        observerModeEnabled: Bool = false,
        mapDisplayLayer: MapDisplayLayer = .hex,
        saveStore: GameSaveStore = GameSaveStore()
    ) {
        var bootstrappedState = StrategicStateBootstrapper().bootstrapIfNeeded(gameState)
        bootstrappedState.playerFaction = playerFaction ?? bootstrappedState.playerFaction
        bootstrappedState.phase = bootstrappedState.phase.normalized(
            forActiveFaction: bootstrappedState.activeFaction,
            playerFaction: bootstrappedState.playerFaction
        )
        self.gameState = Self.refreshGeneralAssignments(in: bootstrappedState, registry: generalRegistry)
        self.commandHandler = commandHandler
        self.dataLoader = dataLoader
        self.generalRegistry = generalRegistry
        self.warPipelineMode = warPipelineMode
        self.turnManager = turnManager
        self.selectedUnitId = nil
        self.selectedHex = nil
        self.selectedRegionId = nil
        self.movementHighlights = []
        self.attackHighlights = []
        self.interactionLog = []
        self.lastCommandMessage = nil
        self.lastAgentDecisionRecord = nil
        self.lastWarDirectiveRecords = []
        self.observerModeEnabled = observerModeEnabled
        self.mapDisplayLayer = mapDisplayLayer
        self.hasSavedGame = saveStore.hasSavedGame
        self.saveStatus = nil
        self.saveStore = saveStore
    }

    static func bootstrap() -> AppContainer {
        let dataLoader = DataLoader()
        let saveStore = GameSaveStore()
        let loadedState: GameState?
        let loadFailureMessage: String?
        do {
            loadedState = try saveStore.load()
            loadFailureMessage = nil
        } catch {
            loadedState = nil
            loadFailureMessage = saveStore.hasSavedGame ? Self.saveLoadFailureDetail : nil
        }

        let gameState = loadedState ?? dataLoader.loadInitialGameState()
        let commandHandler = RuleEngine()
        let generalRegistry = (try? dataLoader.loadGeneralRegistry(for: gameState.scenarioId)) ?? .empty
        let guderian = GameAgent.guderian(from: dataLoader, state: gameState)
        var bootstrappedState = Self.refreshGeneralAssignments(
            in: StrategicStateBootstrapper().bootstrapIfNeeded(gameState),
            registry: generalRegistry
        )
        bootstrappedState.playerFaction = playableFaction(
            bootstrappedState.playerFaction,
            in: bootstrappedState
        )
        bootstrappedState.phase = bootstrappedState.phase.normalized(
            forActiveFaction: bootstrappedState.activeFaction,
            playerFaction: bootstrappedState.playerFaction
        )
        let turnManager = TurnManager(
            agent: guderian,
            provider: MockAIClient(),
            providerName: "朝堂系统",
            commandHandler: commandHandler,
            commanderPool: Self.buildCommanderPool(state: bootstrappedState, registry: generalRegistry),
            marshalAgent: Self.buildMarshalAgent(faction: .germany, state: bootstrappedState)
        )
        let container = AppContainer(
            gameState: bootstrappedState,
            commandHandler: commandHandler,
            dataLoader: dataLoader,
            generalRegistry: generalRegistry,
            playerFaction: bootstrappedState.playerFaction,
            turnManager: turnManager,
            warPipelineMode: .marshalDirective,
            saveStore: saveStore
        )
        if loadedState != nil {
            let activeFactionName = Self.displayFactionName(container.gameState.activeFaction)
            container.appendInteractionEvent("继续上次存档：第 \(container.gameState.turn) 回合，\(activeFactionName)行动。")
            container.saveStatus = .success(
                "已载入本地存档",
                detail: "第 \(container.gameState.turn) 回合，\(activeFactionName)行动。"
            )
        } else if let loadFailureMessage {
            container.appendInteractionEvent("读取存档失败，已开启当前战局。")
            container.saveStatus = .failure(
                "读取存档失败",
                detail: "已开启当前战局。\(loadFailureMessage)"
            )
        }
        container.hasSavedGame = saveStore.hasSavedGame
        return container
    }

    func submit(_ command: Command) {
        let stateBeforeCommand = gameState
        let result = commandHandler.execute(command, in: gameState)
        var nextState = StrategicStateBootstrapper().bootstrapIfNeeded(result.state)
        if result.succeeded {
            nextState = applyPlayerCommandBookkeeping(
                command,
                to: nextState,
                previousState: stateBeforeCommand
            )
        }
        gameState = refreshGeneralAssignments(in: nextState)
        lastCommandMessage = commandPanelMessage(for: result)

        let status = result.succeeded ? "已执行" : "被拒绝"
        appendInteractionEvent("军令\(status)：\(Self.displayCommandName(command))。\(commandInteractionDetail(for: result))")
        refreshSelectionAfterStateChange()
        persistCurrentGame()
        runAIIfNeeded()
    }

    func runAIIfNeeded() {
        guard !isRunningAI else {
            return
        }

        gameState = refreshedRuntimeState(gameState)
        guard shouldRunAI(for: gameState.activeFaction, phase: gameState.phase) else {
            return
        }

        isRunningAI = true
        let stateSnapshot = gameState
        let pipelineMode = warPipelineMode
        let observerEnabled = observerModeEnabled

        Task {
            let outcome = await self.runAISequence(
                from: stateSnapshot,
                pipelineMode: pipelineMode,
                observerEnabled: observerEnabled
            )
            await MainActor.run {
                self.gameState = self.refreshedRuntimeState(outcome.state)
                self.lastAgentDecisionRecord = outcome.record
                self.lastWarDirectiveRecords = outcome.directiveRecords
                self.lastCommandMessage = outcome.record.errors.isEmpty
                    ? "自动回合完成。"
                    : "自动回合完成，存在 \(outcome.record.errors.count) 项问题。"
                self.appendInteractionEvent("自动回合完成，结算 \(outcome.record.commandResults.count) 条军令结果。")
                self.isRunningAI = false
                self.refreshSelectionAfterStateChange()
                self.persistCurrentGame()
            }
        }
    }

    func handleBoardTap(_ coord: HexCoord) {
        guard gameState.map.contains(coord) else {
            return
        }

        selectedHex = coord
        selectedRegionId = mapDisplayAdapter.regionId(for: coord)
        appendInteractionEvent(selectionMessage(for: coord))

        let displayedDivisions = mapDisplayAdapter.divisions(displayedAt: coord, viewerFaction: playerFaction)
        if let attacker = selectedActionDivision,
           let enemy = displayedDivisions.first(where: { $0.faction != attacker.faction }) {
            submit(.attack(attackerId: attacker.id, targetId: enemy.id))
            return
        }

        if let tappedDivision = displayedDivisions.first {
            handleDivisionTap(tappedDivision)
            return
        }

        if let division = selectedActionDivision {
            submitMove(division: division, tappedHex: coord)
        } else {
            selectedUnitId = nil
            clearHighlights()
        }
    }

    func holdSelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent("固守被拒绝：未选择可行动己方军队。")
            return
        }

        submit(.hold(divisionId: division.id))
    }

    func allowRetreatSelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent("准退被拒绝：未选择可行动己方军队。")
            return
        }

        submit(.allowRetreat(divisionId: division.id))
    }

    func resupplySelected() {
        guard let division = selectedActionDivision else {
            appendInteractionEvent("整军被拒绝：未选择可行动己方军队。")
            return
        }

        submit(.resupply(divisionId: division.id))
    }

    func orderSelectedGeneralHoldLine() {
        guard let zone = selectedGeneralCommandZone else {
            appendInteractionEvent("总管军令被拒绝：未选择己方行军防区。")
            return
        }

        let directive = ZoneDirective(
            zoneId: zone.id,
            defense: DefenseParameters(
                targetReserves: max(1, min(2, zone.unitsDepth.count)),
                stance: .holdLine
            ),
            category: .defense,
            tactic: .holdPosition
        )
        submitPlayerDirective(
            directive,
            sourceRegionId: sourceRegionId(for: zone, targetZoneId: nil),
            targetRegionId: nil
        )
    }

    func orderSelectedGeneralAttackRegion() {
        guard let target = selectedAttackTarget else {
            appendInteractionEvent("总管军令被拒绝：请选择敌方前线州郡。")
            return
        }
        guard let zone = selectedGeneralCommandZone else {
            appendInteractionEvent("总管军令被拒绝：没有可用己方来源防区。")
            return
        }

        let directive = ZoneDirective(
            zoneId: zone.id,
            attack: AttackParameters(
                targetTheaterId: TheaterId(target.zone.id.rawValue),
                weightedRegions: [target.region.id],
                intensity: .limitedCounter,
                focusRegionId: target.region.id,
                maxCommittedUnits: max(1, min(3, zone.unitsFront.count + zone.unitsDepth.count))
            ),
            category: .offense,
            tactic: .standardAttack,
            commandTarget: .region(target.region.id)
        )
        submitPlayerDirective(
            directive,
            sourceRegionId: sourceRegionId(for: zone, targetZoneId: target.zone.id),
            targetRegionId: target.region.id
        )
    }

    func queueProduction(_ kind: ProductionKind) {
        guard !observerModeEnabled else {
            appendInteractionEvent("生产被拒绝：观察模式只读。")
            return
        }

        submit(.queueProduction(kind: kind))
    }

    func endTurn() {
        submit(.endTurn)
    }

    func advanceOrRunAI() {
        if shouldRunAI(for: gameState.activeFaction, phase: gameState.phase) {
            runAIIfNeeded()
        } else {
            endTurn()
        }
    }

    func setObserverModeEnabled(_ enabled: Bool) {
        observerModeEnabled = enabled
    }

    func setMapDisplayLayer(_ layer: MapDisplayLayer) {
        mapDisplayLayer = layer
    }

    var playableFactions: [Faction] {
        Self.playableFactions(in: gameState)
    }

    func setPlayerFaction(_ faction: Faction) {
        let playable = Self.playableFactions(in: gameState)
        guard playable.contains(faction),
              faction != gameState.playerFaction else {
            return
        }

        isRunningAI = false
        gameState.playerFaction = faction
        gameState.phase = gameState.phase.normalized(
            forActiveFaction: gameState.activeFaction,
            playerFaction: gameState.playerFaction
        )
        clearSelection()
        let factionName = Self.displayFactionName(faction)
        lastCommandMessage = "已改由\(factionName)下令。"
        appendInteractionEvent("本局执掌势力改为\(factionName)。")
        persistCurrentGame()
        runAIIfNeeded()
    }

    func startNewGame() {
        isRunningAI = false
        let preferredFaction = playerFaction
        var newState = dataLoader.loadInitialGameState()
        newState.playerFaction = Self.playableFaction(preferredFaction, in: newState)
        newState.phase = newState.phase.normalized(
            forActiveFaction: newState.activeFaction,
            playerFaction: newState.playerFaction
        )
        replaceGameState(newState, clearingLog: true)
        lastCommandMessage = "新局已开始。"
        appendInteractionEvent("新局已开始：\(Self.scenarioTitle(for: gameState.scenarioId))，\(Self.displayFactionName(playerFaction))执掌。")
        persistCurrentGame()
        runAIIfNeeded()
    }

    func continueSavedGame() {
        guard saveStore.hasSavedGame else {
            hasSavedGame = false
            lastCommandMessage = "没有可继续的存档。"
            saveStatus = .notice("没有可继续的存档", detail: "可从局势菜单开启新局。")
            appendInteractionEvent("继续被拒绝：没有可继续的存档。")
            return
        }

        do {
            var savedState = try saveStore.load()
            savedState.playerFaction = Self.playableFaction(savedState.playerFaction, in: savedState)
            savedState.phase = savedState.phase.normalized(
                forActiveFaction: savedState.activeFaction,
                playerFaction: savedState.playerFaction
            )
            isRunningAI = false
            replaceGameState(savedState, clearingLog: true)
            hasSavedGame = true
            lastCommandMessage = "已读取本地存档。"
            let activeFactionName = Self.displayFactionName(gameState.activeFaction)
            saveStatus = .success(
                "已读取本地存档",
                detail: "第 \(gameState.turn) 回合，\(activeFactionName)行动。"
            )
            appendInteractionEvent("继续上次存档：第 \(gameState.turn) 回合，\(activeFactionName)行动。")
            runAIIfNeeded()
        } catch {
            hasSavedGame = saveStore.hasSavedGame
            lastCommandMessage = "读取存档失败。"
            saveStatus = .failure("读取存档失败", detail: Self.saveLoadFailureDetail)
            appendInteractionEvent("读取存档失败，请重试或开启新局。")
        }
    }

    func resetGame() {
        isRunningAI = false
        let deletionErrorMessage: String?
        do {
            try saveStore.deleteSave()
            deletionErrorMessage = nil
        } catch {
            deletionErrorMessage = Self.saveDeleteFailureDetail
        }
        let preferredFaction = playerFaction
        var newState = dataLoader.loadInitialGameState()
        newState.playerFaction = Self.playableFaction(preferredFaction, in: newState)
        newState.phase = newState.phase.normalized(
            forActiveFaction: newState.activeFaction,
            playerFaction: newState.playerFaction
        )
        replaceGameState(newState, clearingLog: true)
        hasSavedGame = saveStore.hasSavedGame
        lastCommandMessage = "已重置为新局。"
        if let deletionErrorMessage {
            saveStatus = .failure(
                "删除存档失败",
                detail: "已重置局势，但旧存档仍在本地。\(deletionErrorMessage)"
            )
            appendInteractionEvent("删除存档失败，旧存档仍在本地。")
        } else {
            saveStatus = .notice("已重置局势", detail: "当前没有本地存档。")
        }
        let resetMessage = hasSavedGame ? "已重置局势，但旧存档仍在本地。" : "已重置局势，当前没有本地存档。"
        appendInteractionEvent(resetMessage)
        runAIIfNeeded()
    }

    var selectedDivision: Division? {
        guard let selectedUnitId else {
            return nil
        }
        return gameState.division(id: selectedUnitId)
    }

    var selectedRegionInspectorState: RegionInspectorState? {
        guard let selectedRegionId else {
            return nil
        }
        return mapDisplayAdapter.inspectorState(for: selectedRegionId, selectedHex: selectedHex, viewerFaction: playerFaction)
    }

    var selectedUnitInspectorStrategicState: UnitInspectorStrategicState? {
        guard let selectedDivision else {
            return nil
        }
        return mapDisplayAdapter.unitInspectorState(for: selectedDivision)
    }

    var selectedGeneralCommandZone: FrontZone? {
        inferredPlayerCommandZone()
    }

    var selectedGeneral: GeneralData? {
        generalRegistry.general(id: selectedGeneralAssignment?.generalId)
    }

    var selectedGeneralAssignment: GeneralAssignment? {
        selectedGeneralCommandZone?.generalAssignment
    }

    var selectedGeneralAssignedDivisions: [Division] {
        guard let assignment = selectedGeneralAssignment else {
            return []
        }
        let assignedIds = Set(assignment.assignedDivisionIds)
        return gameState.divisions
            .filter { assignedIds.contains($0.id) }
            .sorted { $0.id < $1.id }
    }

    var selectedGeneralHQUnderAttack: Bool {
        guard let zone = selectedGeneralCommandZone else {
            return false
        }
        return GeneralDispatcher(registry: generalRegistry).isHQUnderAttack(
            zone: zone,
            map: gameState.map
        )
    }

    var selectedGeneralTargetRegion: RegionNode? {
        selectedRegionId.flatMap { gameState.map.region(id: $0) }
    }

    var selectedGeneralTargetZone: FrontZone? {
        guard let selectedRegionId else {
            return nil
        }
        return gameState.warDeploymentState.zone(for: selectedRegionId)
    }

    var selectedGeneralPlannedOperations: [PlayerPlannedOperation] {
        let zoneId = selectedGeneralCommandZone?.id
        return Array(gameState.playerCommandState.plannedOperations
            .filter { operation in
                operation.turn == gameState.turn &&
                    (zoneId == nil || operation.zoneId == zoneId)
            }
            .suffix(5))
    }

    var canOrderSelectedGeneralHoldLine: Bool {
        canIssuePlayerDirective && selectedGeneralCommandZone != nil
    }

    var canOrderSelectedGeneralAttackRegion: Bool {
        canIssuePlayerDirective && selectedAttackTarget != nil && selectedGeneralCommandZone != nil
    }

    var playerDiplomacyTarget: Faction? {
        let candidates = Set(gameState.diplomacyState.countries.map(\.faction))
            .subtracting([playerFaction])
        let orderedCandidates = Faction.suitangTurnOrder.filter { candidates.contains($0) } +
            Faction.legacyCombatants.filter { candidates.contains($0) } +
            candidates
                .subtracting(Set(Faction.suitangTurnOrder + Faction.legacyCombatants))
                .sorted { $0.rawValue < $1.rawValue }
        return orderedCandidates.first {
            gameState.diplomacyState.relationStatus(between: playerFaction, and: $0).isHostile
        }
    }

    var canIssuePlayerDiplomacy: Bool {
        canIssuePlayerDirective && playerDiplomacyTarget != nil
    }

    var submissionPresenceSummaries: [SubmissionPresenceSummary] {
        gameState.diplomacyState.submittedTargetFactions().map { faction in
            SubmissionPresenceSummary(
                faction: faction,
                activeDivisionCount: gameState.divisions.filter {
                    $0.faction == faction && !$0.isDestroyed
                }.count,
                controlledPassableHexCount: gameState.map.tiles.values.filter {
                    $0.controller == faction && $0.isPassable
                }.count
            )
        }
    }

    func canResolveSubmissionHandoff(for submitted: Faction) -> Bool {
        canIssuePlayerDirective &&
            gameState.diplomacyState.canResolveSubmissionHandoff(
                submitted: submitted,
                recipient: playerFaction
            ) &&
            submissionPresenceSummaries.first { $0.faction == submitted }?.hasRuntimePresence == true
    }

    func canGovernSelectedRegion(_ policy: RegionGovernancePolicy) -> Bool {
        guard let region = selectedGovernableRegion(),
              policy.canApply(to: region) else {
            return false
        }
        return gameState.economyState
            .ledger(for: playerFaction)
            .stockpile
            .canAfford(policy.cost)
    }

    var displayEventLog: [GameLogEntry] {
        Array((gameState.eventLog + interactionLog).suffix(80))
    }

    var selectedUnitCanAct: Bool {
        selectedActionDivision != nil
    }

    private var selectedActionDivision: Division? {
        guard !observerModeEnabled else {
            return nil
        }
        let normalizedPhase = gameState.phase.normalized(
            forActiveFaction: gameState.activeFaction,
            playerFaction: playerFaction
        )
        guard let division = selectedDivision,
              division.faction == playerFaction,
              gameState.activeFaction == playerFaction,
              normalizedPhase.allowsPlayerInput,
              !division.hasActed else {
            return nil
        }

        return division
    }

    private var canIssuePlayerDirective: Bool {
        let normalizedPhase = gameState.phase.normalized(
            forActiveFaction: gameState.activeFaction,
            playerFaction: playerFaction
        )
        return !observerModeEnabled &&
            gameState.activeFaction == playerFaction &&
            normalizedPhase.allowsPlayerInput
    }

    private var selectedAttackTarget: (region: RegionNode, zone: FrontZone)? {
        guard let selectedRegionId,
              let region = gameState.map.region(id: selectedRegionId),
              let targetZone = gameState.warDeploymentState.zone(for: selectedRegionId),
              gameState.diplomacyState.canAttack(playerFaction, targetZone.faction) else {
            return nil
        }
        return (region, targetZone)
    }

    func proposeTruceToDiplomacyTarget() {
        submitDiplomacyStatus(.truce)
    }

    func acceptSubmissionFromDiplomacyTarget() {
        submitDiplomacyStatus(.submitted)
    }

    func resolveSubmissionHandoff(for submitted: Faction) {
        guard canResolveSubmissionHandoff(for: submitted) else {
            lastCommandMessage = "\(Self.displayFactionName(submitted))归附交接暂不可执行。"
            appendInteractionEvent(lastCommandMessage ?? "归附交接不可用。")
            return
        }

        submit(.resolveSubmissionHandoff(submitted: submitted, recipient: playerFaction))
    }

    func governSelectedRegion(_ policy: RegionGovernancePolicy) {
        guard let region = selectedGovernableRegion(),
              let selectedRegionId else {
            lastCommandMessage = "当前没有可经营的己方州郡。"
            appendInteractionEvent(lastCommandMessage ?? "州郡经营暂不可用。")
            return
        }

        guard policy.canApply(to: region) else {
            lastCommandMessage = "\(Self.displayMapName(region.name, fallback: "该州郡"))暂无可执行的\(policy.displayName)。"
            appendInteractionEvent(lastCommandMessage ?? "州郡经营暂不可用。")
            return
        }

        submit(.governRegion(regionId: selectedRegionId, policy: policy))
    }

    private var mapDisplayAdapter: MapDisplayAdapter {
        MapDisplayAdapter(state: gameState, revealAll: observerModeEnabled)
    }

    private func refreshedRuntimeState(_ state: GameState) -> GameState {
        refreshGeneralAssignments(
            in: StrategicStateBootstrapper().refreshRuntimeState(state)
        )
    }

    private func submitDiplomacyStatus(_ status: DiplomaticStatus) {
        guard canIssuePlayerDiplomacy,
              let target = playerDiplomacyTarget else {
            lastCommandMessage = "当前没有可执行的外交对象。"
            appendInteractionEvent(lastCommandMessage ?? "外交行动暂不可用。")
            return
        }

        submit(.updateDiplomacy(issuer: playerFaction, target: target, status: status))
    }

    private func selectedGovernableRegion() -> RegionNode? {
        guard canIssuePlayerDirective,
              let selectedRegionId,
              let region = gameState.map.region(id: selectedRegionId),
              region.controller == playerFaction,
              region.displayHexes.contains(where: { gameState.map.tile(at: $0)?.controller == playerFaction }) else {
            return nil
        }
        return region
    }

    private func replaceGameState(_ state: GameState, clearingLog: Bool) {
        gameState = refreshGeneralAssignments(
            in: StrategicStateBootstrapper().bootstrapIfNeeded(state)
        )
        clearSelection()
        if clearingLog {
            interactionLog = []
        }
        lastAgentDecisionRecord = nil
        lastWarDirectiveRecords = []
    }

    private func refreshGeneralAssignments(in state: GameState) -> GameState {
        Self.refreshGeneralAssignments(in: state, registry: generalRegistry)
    }

    private static func refreshGeneralAssignments(
        in state: GameState,
        registry: GeneralRegistry
    ) -> GameState {
        guard !registry.allGenerals.isEmpty else {
            return state
        }
        var next = state
        next.warDeploymentState = GeneralDispatcher(registry: registry).assignGenerals(
            to: state.warDeploymentState,
            map: state.map
        )
        return next
    }

    private func applyPlayerCommandBookkeeping(
        _ command: Command,
        to state: GameState,
        previousState: GameState
    ) -> GameState {
        var next = state
        if command == .endTurn || next.activeFaction != previousState.activeFaction || next.turn != previousState.turn {
            next.playerCommandState.clearTurnLocks()
            return next
        }

        let previousPhase = previousState.phase.normalized(
            forActiveFaction: previousState.activeFaction,
            playerFaction: playerFaction
        )
        guard let divisionId = command.actingDivisionId,
              previousState.activeFaction == playerFaction,
              previousPhase.allowsPlayerInput,
              previousState.division(id: divisionId)?.faction == playerFaction else {
            return next
        }

        next.playerCommandState.lockDivision(divisionId)
        return registerPlayerIntervention(for: divisionId, in: next)
    }

    private func registerPlayerIntervention(for divisionId: String, in state: GameState) -> GameState {
        guard let zoneId = logicalZoneId(for: divisionId, in: state.warDeploymentState),
              var zone = state.warDeploymentState.frontZones[zoneId],
              let assignment = zone.generalAssignment else {
            return state
        }

        var next = state
        zone.generalAssignment = assignment.registeringPlayerIntervention(cost: 2)
        next.warDeploymentState.frontZones[zoneId] = zone
        return next
    }

    private func inferredPlayerCommandZone() -> FrontZone? {
        if let division = selectedDivision,
           division.faction == playerFaction,
           let zoneId = gameState.warDeploymentState.zoneId(for: division.coord, map: gameState.map),
           let zone = gameState.warDeploymentState.frontZones[zoneId],
           zone.faction == playerFaction {
            return zone
        }

        if let selectedRegionId,
           let zone = gameState.warDeploymentState.zone(for: selectedRegionId),
           zone.faction == playerFaction {
            return zone
        }

        guard let targetZone = selectedGeneralTargetZone,
              targetZone.faction != playerFaction else {
            return nil
        }

        return playerZonesAdjacent(to: targetZone.id).first
    }

    private func playerZonesAdjacent(to targetZoneId: FrontZoneId) -> [FrontZone] {
        gameState.warDeploymentState.frontZones.values
            .filter { zone in
                zone.faction == playerFaction &&
                    zone.frontSegments.contains { $0.neighborEnemyZone == targetZoneId }
            }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }

    private func sourceRegionId(for zone: FrontZone, targetZoneId: FrontZoneId?) -> RegionId? {
        if let selectedDivision,
           selectedDivision.faction == zone.faction,
           let regionId = selectedDivision.location(in: gameState.map),
           zone.regionIds.contains(regionId) {
            return regionId
        }

        if let selectedRegionId,
           zone.regionIds.contains(selectedRegionId) {
            return selectedRegionId
        }

        if let targetZoneId,
           let segment = zone.frontSegments
            .filter({ $0.neighborEnemyZone == targetZoneId })
            .sorted(by: { $0.regionId.rawValue < $1.regionId.rawValue })
            .first {
            return segment.regionId
        }

        return zone.generalAssignment?.hqRegionId ?? zone.regionIds.first
    }

    private func logicalZoneId(for divisionId: String, in deploymentState: WarDeploymentState) -> FrontZoneId? {
        deploymentState.frontZones.values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .first {
                $0.unitsFront.contains(divisionId)
                    || $0.unitsDepth.contains(divisionId)
                    || $0.unitsGarrison.contains(divisionId)
            }?
            .id
    }

    private func submitPlayerDirective(
        _ directive: ZoneDirective,
        sourceRegionId: RegionId?,
        targetRegionId: RegionId?
    ) {
        guard canIssuePlayerDirective else {
            appendInteractionEvent("总管军令被拒绝：当前不是玩家军令阶段。")
            return
        }
        guard gameState.warDeploymentState.frontZones[directive.zoneId]?.faction == playerFaction else {
            appendInteractionEvent("总管军令被拒绝：来源防区不由玩家控制。")
            return
        }

        let startState = refreshedRuntimeState(gameState)
        guard let refreshedZone = startState.warDeploymentState.frontZones[directive.zoneId],
              refreshedZone.faction == playerFaction else {
            appendInteractionEvent("总管军令被拒绝：来源防区在刷新后发生变化。")
            return
        }
        let lockedIds = startState.playerCommandState.micromanagedDivisionIds
        let execution = WarCommandExecutor(commandHandler: commandHandler).execute(
            directive,
            in: startState,
            excluding: lockedIds
        )

        var nextState = refreshGeneralAssignments(in: execution.finalState)
        let commandSummaries = execution.commandResults.enumerated().map { index, result in
            CommandResultSummary.directiveCommand(
                directiveIndex: 0,
                commandIndex: index,
                directive: directive,
                command: execution.generatedCommands[index],
                result: result
            )
        }
        var diagnostics: [String] = []
        if execution.generatedCommands.isEmpty {
            diagnostics.append("玩家方面军令未形成可执行行动。")
        }
        let rejected = commandSummaries.filter { !$0.executed }
        if !rejected.isEmpty {
            diagnostics.append("\(rejected.count) 条军令未通过战局判定。")
        }
        if !lockedIds.isEmpty {
            diagnostics.append("\(lockedIds.count) 支已微操军队被排除。")
        }

        let record = WarDirectiveRecord(
            id: "player_directive_turn_\(startState.turn)_\(directive.zoneId.rawValue)_\(directive.type.rawValue)_\(targetRegionId?.rawValue ?? "hold")",
            issuerId: "player",
            turn: startState.turn,
            faction: playerFaction,
            zoneId: directive.zoneId,
            directiveType: directive.type,
            targetRegionIds: targetRegionId.map { [$0] } ?? directive.targetRegionIds,
            commandResults: commandSummaries,
            diagnostics: diagnostics,
            category: directive.category,
            tactic: directive.tactic,
            commanderAgentId: refreshedZone.generalAssignment?.generalId,
            commandTarget: directive.commandTarget
        )

        nextState.warDirectiveRecords.append(record)
        nextState.playerCommandState.recordOperation(
            PlayerPlannedOperation(
                id: "player_operation_turn_\(startState.turn)_\(directive.zoneId.rawValue)_\(directive.type.rawValue)_\(targetRegionId?.rawValue ?? "hold")",
                turn: startState.turn,
                zoneId: directive.zoneId,
                faction: playerFaction,
                directiveType: directive.type,
                sourceRegionId: sourceRegionId,
                targetRegionId: targetRegionId,
                createdByGeneralId: refreshedZone.generalAssignment?.generalId
            )
        )

        gameState = nextState
        lastWarDirectiveRecords = Array((lastWarDirectiveRecords + [record]).suffix(12))
        lastCommandMessage = playerDirectiveMessage(for: execution, diagnostics: diagnostics)
        appendInteractionEvent("总管军令已提交：\(Self.displayFrontZoneName(refreshedZone)) \(directive.type.displayName)。")
        refreshSelectionAfterStateChange()
        persistCurrentGame()
    }

    private func playerDirectiveMessage(
        for execution: WarCommandExecutionResult,
        diagnostics: [String]
    ) -> String {
        let acceptedCount = execution.commandResults.filter(\.succeeded).count
        let totalCount = execution.generatedCommands.count
        if totalCount == 0 {
            return diagnostics.first ?? "总管军令未形成行动。"
        }
        if acceptedCount == totalCount {
            return "总管军令完成 \(acceptedCount) 条。"
        }
        return "总管军令完成 \(acceptedCount) 条，尝试 \(totalCount) 条。"
    }

    private func shouldRunAI(for faction: Faction, phase: GamePhase) -> Bool {
        let normalizedPhase = phase.normalized(forActiveFaction: faction, playerFaction: playerFaction)
        if faction == playerFaction {
            return observerModeEnabled && normalizedPhase.allowsPlayerInput
        }

        switch normalizedPhase {
        case .germanAI:
            return true
        case .alliedPlayer:
            return observerModeEnabled
        case .aiCommand:
            return true
        case .playerCommand:
            return observerModeEnabled
        case .resolution:
            return false
        }
    }

    private func runAISequence(
        from state: GameState,
        pipelineMode: WarPipelineMode,
        observerEnabled: Bool
    ) async -> AgentTurnOutcome {
        var currentState = refreshedRuntimeState(state)
        var lastOutcome: AgentTurnOutcome?
        let maxSteps = observerEnabled ? 2 : 1

        for _ in 0..<maxSteps {
            currentState = refreshedRuntimeState(currentState)
            guard shouldRunAIInSnapshot(state: currentState, observerEnabled: observerEnabled) else {
                break
            }

            let manager = turnManager(for: currentState.activeFaction, state: currentState)
            let outcome = await manager.runAITurn(
                state: currentState,
                faction: currentState.activeFaction,
                pipelineMode: pipelineMode
            )
            currentState = refreshedRuntimeState(outcome.state)
            lastOutcome = AgentTurnOutcome(
                state: currentState,
                record: outcome.record,
                directiveRecords: (lastOutcome?.directiveRecords ?? []) + outcome.directiveRecords
            )
        }

        return lastOutcome ?? AgentTurnOutcome(
            state: currentState,
            record: AgentDecisionRecord(
                id: "agent_noop_turn_\(currentState.turn)",
                turn: currentState.turn,
                agentId: "system",
                provider: "朝堂系统",
                contextSummary: "当前没有可自动执行的势力。",
                rawJSON: nil,
                parsedIntent: nil,
                commandResults: [],
                errors: []
            )
        )
    }

    private func shouldRunAIInSnapshot(state: GameState, observerEnabled: Bool) -> Bool {
        let normalizedPhase = state.phase.normalized(
            forActiveFaction: state.activeFaction,
            playerFaction: playerFaction
        )
        if state.activeFaction == playerFaction {
            return observerEnabled && normalizedPhase.allowsPlayerInput
        }

        switch normalizedPhase {
        case .germanAI:
            return true
        case .alliedPlayer:
            return observerEnabled
        case .aiCommand:
            return true
        case .playerCommand:
            return observerEnabled
        case .resolution:
            return false
        }
    }

    private func turnManager(for faction: Faction, state: GameState) -> TurnManager {
        if faction == .germany, let turnManager, generalRegistry.allGenerals.isEmpty {
            return turnManager
        }

        let agent: GameAgent
        switch faction {
        case .germany:
            agent = GameAgent.guderian(from: dataLoader, state: state)
        case .allies:
            let assignedIds = state.divisions
                .filter { $0.faction == .allies && !$0.isDestroyed }
                .map(\.id)
            agent = GameAgent.sample(
                id: "allied_mock_commander",
                name: "当前战局总管",
                faction: .allies,
                role: .armyCommander,
                assignedDivisionIds: assignedIds
            )
        default:
            let assignedIds = state.divisions
                .filter { $0.faction == faction && !$0.isDestroyed }
                .map(\.id)
            agent = GameAgent.sample(
                id: "mock_commander_\(faction.rawValue)",
                name: "\(Self.displayFactionName(faction))临时总管",
                faction: faction,
                role: .armyCommander,
                assignedDivisionIds: assignedIds
            )
        }

        return TurnManager(
            agent: agent,
            provider: MockAIClient(),
            providerName: "朝堂系统",
            commandHandler: commandHandler,
            commanderPool: Self.buildCommanderPool(state: state, registry: generalRegistry),
            marshalAgent: Self.buildMarshalAgent(faction: faction, state: state)
        )
    }

    private static func buildCommanderPool(
        state: GameState,
        registry: GeneralRegistry = .empty
    ) -> TheaterCommanderPool {
        if !registry.allGenerals.isEmpty {
            return GeneralDispatcher(registry: registry).commanderPool(for: state)
        }

        let agents: [any ZoneCommanderProviding] = state.warDeploymentState.frontZones.values
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map { zone in
                let factionName = Self.displayFactionName(zone.faction)
                let config = ZoneCommanderAgentConfig(
                    id: "auto_\(zone.id.rawValue)",
                    name: "\(factionName)总管（\(Self.displayFrontZoneName(zone))）",
                    faction: zone.faction,
                    assignedZoneId: zone.id,
                    skills: [],
                    commandStyle: ZoneCommanderAgentConfig.CommandStyle.defaultForFaction(zone.faction)
                )
                return ZoneCommanderAgent(config: config)
            }
        return TheaterCommanderPool(commanders: agents)
    }

    private static func buildMarshalAgent(faction: Faction, state: GameState) -> MarshalAgent {
        MarshalAgent(config: MarshalAgentConfig.automatic(for: faction, state: state))
    }

    private static func playableFactions(in state: GameState) -> [Faction] {
        let factionSet = Set(state.diplomacyState.countries.map(\.faction) + state.divisions.map(\.faction))
        guard !factionSet.isEmpty else {
            return [state.playerFaction]
        }
        let preferred = Faction.suitangTurnOrder.filter { factionSet.contains($0) }
        let legacy = state.scenarioId.hasPrefix("wude_618")
            ? []
            : Faction.legacyCombatants.filter { factionSet.contains($0) }
        let known = Set(preferred + legacy)
        let remaining = factionSet
            .subtracting(known)
            .sorted { $0.rawValue < $1.rawValue }
        return preferred + legacy + remaining
    }

    private static func playableFaction(_ faction: Faction, in state: GameState) -> Faction {
        let playable = playableFactions(in: state)
        if playable.contains(faction) {
            return faction
        }
        if state.scenarioId.hasPrefix("wude_618"), playable.contains(.tang) {
            return .tang
        }
        return playable.first ?? faction
    }

    private func handleDivisionTap(_ division: Division) {
        if observerModeEnabled {
            selectDivision(division)
            appendInteractionEvent("查看军队：\(Self.displayDivisionName(division))。")
            return
        }

        if division.faction == playerFaction {
            selectDivision(division)
            appendInteractionEvent("选择军队：\(Self.displayDivisionName(division))。")
            return
        }

        if let attacker = selectedActionDivision {
            submit(.attack(attackerId: attacker.id, targetId: division.id))
        } else {
            selectDivision(division)
            appendInteractionEvent("选择敌军：\(Self.displayDivisionName(division))。")
        }
    }

    private func selectDivision(_ division: Division) {
        selectedUnitId = division.id
        selectedHex = mapDisplayAdapter.unitDisplayHex(for: division) ?? division.coord
        selectedRegionId = division.location(in: gameState.map)
        refreshHighlights()
    }

    private func refreshSelectionAfterStateChange() {
        if let selectedUnitId,
           gameState.division(id: selectedUnitId) == nil {
            self.selectedUnitId = nil
        }

        if let selectedDivision {
            selectedHex = mapDisplayAdapter.unitDisplayHex(for: selectedDivision) ?? selectedDivision.coord
            selectedRegionId = selectedDivision.location(in: gameState.map)
        }

        refreshHighlights()
    }

    private func refreshHighlights() {
        guard let division = selectedActionDivision else {
            clearHighlights()
            return
        }

        movementHighlights = MovementRules().movementRange(for: division, in: gameState)
        attackHighlights = Set(
            gameState.divisions
                .filter { $0.faction != division.faction && division.coord.distance(to: $0.coord) <= division.range }
                .map(\.coord)
        )
    }

    private func clearHighlights() {
        movementHighlights = []
        attackHighlights = []
    }

    private func clearSelection() {
        selectedUnitId = nil
        selectedHex = nil
        selectedRegionId = nil
        clearHighlights()
    }

    private func submitMove(division: Division, tappedHex: HexCoord) {
        submit(.move(divisionId: division.id, destination: tappedHex))
    }

    private func selectionMessage(for coord: HexCoord) -> String {
        guard let selectedRegionId,
              let region = gameState.map.region(id: selectedRegionId) else {
            return "选择未编入州郡的地块。"
        }
        return "选择州郡：\(Self.displayMapName(region.name, fallback: "州郡"))。"
    }

    private func appendInteractionEvent(_ message: String) {
        interactionLog.append(
            GameLogEntry(
                turn: gameState.turn,
                faction: gameState.activeFaction,
                phase: gameState.phase,
                message: message,
                createdAt: Date()
            )
        )

        if interactionLog.count > 80 {
            interactionLog.removeFirst(interactionLog.count - 80)
        }
    }

    private func persistCurrentGame() {
        do {
            try saveStore.save(gameState)
            hasSavedGame = true
            let activeFactionName = Self.displayFactionName(gameState.activeFaction)
            saveStatus = .success(
                "本地存档已更新",
                detail: "第 \(gameState.turn) 回合，\(activeFactionName)行动。"
            )
        } catch {
            hasSavedGame = saveStore.hasSavedGame
            lastCommandMessage = "本地存档失败。"
            saveStatus = .failure("本地存档失败", detail: Self.saveWriteFailureDetail)
            appendInteractionEvent("本地存档失败，请稍后重试。")
        }
    }

    private static let saveLoadFailureDetail = "本地存档无法读取，可能已损坏或版本不兼容。"
    private static let saveDeleteFailureDetail = "旧存档暂时无法删除，可稍后重试。"
    private static let saveWriteFailureDetail = "本地存档写入失败，请检查设备存储空间后重试。"

    private static func scenarioTitle(for scenarioId: String) -> String {
        switch scenarioId {
        case "wude_618_guanzhong_luoyang":
            return "武德元年：关中河洛争衡"
        case "mapeditor_suitang_scenario":
            return "自定战局"
        case "ardennes_v0", "mapeditor_scenario":
            return "当前战局"
        default:
            return "当前战局"
        }
    }

    private func commandPanelMessage(for result: CommandResult) -> String {
        guard result.succeeded else {
            return "军令被拒绝，请重新选择目标或检查行动条件。"
        }
        return "军令已执行。"
    }

    private func commandInteractionDetail(for result: CommandResult) -> String {
        guard result.succeeded else {
            let reasons = result.validation.errors.map(\.displayName).joined(separator: "、")
            return reasons.isEmpty ? "战局判定未成。" : "原因：\(reasons)。"
        }
        return "已交由战局判定。"
    }

    private static func displayFactionName(_ faction: Faction) -> String {
        switch faction {
        case .germany, .allies:
            return "旧剧本势力"
        default:
            return faction.displayName
        }
    }

    private static func displayCommandName(_ command: Command) -> String {
        switch command {
        case .updateDiplomacy(let issuer, let target, let status):
            return "外交：\(displayFactionName(issuer))与\(displayFactionName(target))\(status.displayName)"
        case .resolveSubmissionHandoff(let submitted, let recipient):
            return "归附交接：\(displayFactionName(submitted))至\(displayFactionName(recipient))"
        default:
            return command.displayName
        }
    }

    private static func displayDivisionName(_ division: Division) -> String {
        let fallback = "\(displayFactionName(division.faction))\(division.unitKindDisplayName)"
        let trimmed = division.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallback
        }

        let sanitized = sanitizeRawUnitIdentifier(in: trimmed)
            .replacingOccurrences(of: "德军", with: "旧剧本")
            .replacingOccurrences(of: "盟军", with: "旧剧本")
            .replacingOccurrences(of: "装甲", with: "甲骑")
            .replacingOccurrences(of: "摩托化", with: "骑军")
            .replacingOccurrences(of: "炮兵", with: "弓弩")
            .replacingOccurrences(of: "步兵", with: "步卒")
            .replacingOccurrences(of: "反甲骑", with: "拒马弩")
            .replacingOccurrences(of: "反装甲", with: "拒马弩")
            .replacingOccurrences(of: "师", with: "军")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? fallback : sanitized
    }

    private static func displayFrontZoneName(_ zone: FrontZone) -> String {
        displayMapName(zone.name, fallback: "行军防区")
    }

    private static func displayMapName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallback
        }

        let sanitized = sanitizeRawMapIdentifier(in: trimmed)
            .replacingOccurrences(of: "巴斯托涅", with: "旧战局要地")
            .replacingOccurrences(of: "圣维特", with: "旧战局要地")
            .replacingOccurrences(of: "阿登", with: "旧战局")
            .replacingOccurrences(of: "Bastogne", with: "旧战局要地")
            .replacingOccurrences(of: "St. Vith", with: "旧战局要地")
            .replacingOccurrences(of: "St Vith", with: "旧战局要地")
            .replacingOccurrences(of: "Ardennes", with: "旧战局")
            .replacingOccurrences(of: "Sedan", with: "旧战局要地")
            .replacingOccurrences(of: "德军", with: "旧剧本")
            .replacingOccurrences(of: "盟军", with: "旧剧本")
            .replacingOccurrences(of: "战区", with: "方面")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? fallback : sanitized
    }

    private static func sanitizeRawUnitIdentifier(in name: String) -> String {
        name.replacingOccurrences(
            of: #"\b(division|unit)_[A-Za-z0-9_\-]+\b"#,
            with: "相关军队",
            options: .regularExpression
        )
    }

    private static func sanitizeRawMapIdentifier(in name: String) -> String {
        name.replacingOccurrences(
            of: #"\b(region|theater|front_zone|front|obj|objective|hex)_[A-Za-z0-9_\-]+\b"#,
            with: "相关地点",
            options: .regularExpression
        )
        .replacingOccurrences(
            of: #"\b(germany|france|allied|axis)_[A-Za-z0-9_\-]+\b"#,
            with: "相关旧战局",
            options: .regularExpression
        )
    }

}
