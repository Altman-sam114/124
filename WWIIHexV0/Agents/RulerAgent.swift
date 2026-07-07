import Foundation

struct RulerDirectiveAdjustment: Equatable {
    let envelope: DirectiveEnvelope
    let record: RulerDecisionRecord
}

struct RulerAgentConfig: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let faction: Faction
    let countryId: CountryId?
    let aggression: Int
    let coalitionDiscipline: Int
    let riskTolerance: Int

    init(
        id: String,
        name: String,
        faction: Faction,
        countryId: CountryId?,
        aggression: Int,
        coalitionDiscipline: Int,
        riskTolerance: Int
    ) {
        self.id = id
        self.name = name
        self.faction = faction
        self.countryId = countryId
        self.aggression = max(0, min(100, aggression))
        self.coalitionDiscipline = max(0, min(100, coalitionDiscipline))
        self.riskTolerance = max(0, min(100, riskTolerance))
    }
}

struct RulerAgent {
    let config: RulerAgentConfig

    func adjust(envelope: DirectiveEnvelope, in state: GameState) -> RulerDirectiveAdjustment {
        let snapshot = RulerStrategicSnapshot(faction: config.faction, state: state)
        let posture = choosePosture(snapshot: snapshot)
        let directives = envelope.directives.map { adjust(directive: $0, posture: posture, snapshot: snapshot) }
        let preferredZoneId = choosePreferredZoneId(snapshot: snapshot)
        let targetRegionIds = chooseTargetRegionIds(directives: directives, snapshot: snapshot)
        let record = RulerDecisionRecord(
            id: "ruler_\(config.id)_turn_\(state.turn)_\(config.faction.rawValue)",
            turn: state.turn,
            faction: config.faction,
            countryId: config.countryId,
            rulerAgentId: config.id,
            posture: posture,
            preferredFrontZoneId: preferredZoneId,
            targetRegionIds: targetRegionIds,
            attackThresholdAdjustment: thresholdAdjustment(for: posture),
            reserveBias: reserveBias(for: posture),
            diplomacySummary: state.diplomacyState.summary(for: config.faction),
            rationale: rationale(for: posture, snapshot: snapshot)
        )
        let adjustedEnvelope = DirectiveEnvelope(
            schemaVersion: envelope.schemaVersion,
            issuerId: envelope.issuerId,
            turn: envelope.turn,
            directives: directives,
            commanderAgentId: envelope.commanderAgentId,
            theaterContext: appendRulerContext(envelope.theaterContext, record: record)
        )
        return RulerDirectiveAdjustment(envelope: adjustedEnvelope, record: record)
    }

    private func choosePosture(snapshot: RulerStrategicSnapshot) -> RulerStrategicPosture {
        if snapshot.hostileCountryCount > 1 && config.coalitionDiscipline >= 55 {
            return .coalitionMaintenance
        }

        if snapshot.averageZonePressure >= 4 || snapshot.outnumberedFrontZoneCount > snapshot.advantagedFrontZoneCount {
            return .defensive
        }

        if snapshot.staticDefenseStreak >= 2 || snapshot.contestedFriendlyPresenceCount > 0 {
            return .stabilizeFront
        }

        let aggressionScore = config.aggression + config.riskTolerance / 2 + snapshot.advantagedFrontZoneCount * 8
        if aggressionScore >= 95 && snapshot.frontZoneCount > 0 {
            return .offensive
        }

        return snapshot.frontZoneCount > 1 ? .coalitionMaintenance : .stabilizeFront
    }

    private func adjust(
        directive: ZoneDirective,
        posture: RulerStrategicPosture,
        snapshot: RulerStrategicSnapshot
    ) -> ZoneDirective {
        switch (posture, directive.parameters) {
        case (.offensive, .attack(let attack)):
            return ZoneDirective(
                zoneId: directive.zoneId,
                attack: AttackParameters(
                    targetTheaterId: attack.targetTheaterId,
                    weightedRegions: prioritizedRegions(attack.weightedRegions, snapshot: snapshot),
                    intensity: .allOut,
                    focusRegionId: attack.focusRegionId,
                    supportRegionIds: attack.supportRegionIds,
                    convergenceRegionId: attack.convergenceRegionId,
                    coordinatedZoneIds: attack.coordinatedZoneIds,
                    maxCommittedUnits: attack.maxCommittedUnits,
                    exploitDepth: attack.exploitDepth
                ),
                category: directive.category,
                tactic: directive.tactic,
                commandTarget: directive.commandTarget
            )
        case (.defensive, .attack):
            return ZoneDirective(
                zoneId: directive.zoneId,
                defense: DefenseParameters(targetReserves: 2, stance: .holdLine),
                category: .defense,
                tactic: .holdPosition,
                commandTarget: .theater(TheaterId(directive.zoneId.rawValue))
            )
        case (.coalitionMaintenance, .defend(let defense)):
            return ZoneDirective(
                zoneId: directive.zoneId,
                defense: DefenseParameters(
                    targetReserves: max(2, defense.targetReserves),
                    stance: defense.stance,
                    fallbackRegionIds: defense.fallbackRegionIds,
                    counterattackRegionIds: defense.counterattackRegionIds,
                    strongpointRegionIds: defense.strongpointRegionIds,
                    maxFrontCommitment: defense.maxFrontCommitment
                ),
                category: directive.category,
                tactic: directive.tactic,
                commandTarget: directive.commandTarget
            )
        case (.stabilizeFront, .attack(let attack)) where attack.intensity == .allOut:
            return ZoneDirective(
                zoneId: directive.zoneId,
                attack: AttackParameters(
                    targetTheaterId: attack.targetTheaterId,
                    weightedRegions: attack.weightedRegions,
                    intensity: .limitedCounter,
                    focusRegionId: attack.focusRegionId,
                    supportRegionIds: attack.supportRegionIds,
                    convergenceRegionId: attack.convergenceRegionId,
                    coordinatedZoneIds: attack.coordinatedZoneIds,
                    maxCommittedUnits: attack.maxCommittedUnits,
                    exploitDepth: attack.exploitDepth
                ),
                category: directive.category,
                tactic: directive.tactic,
                commandTarget: directive.commandTarget
            )
        case (.stabilizeFront, .defend(let defense)):
            return ZoneDirective(
                zoneId: directive.zoneId,
                defense: DefenseParameters(
                    targetReserves: 1,
                    stance: .flexible,
                    fallbackRegionIds: defense.fallbackRegionIds,
                    counterattackRegionIds: defense.counterattackRegionIds,
                    strongpointRegionIds: defense.strongpointRegionIds,
                    maxFrontCommitment: defense.maxFrontCommitment
                ),
                category: .defense,
                tactic: .holdPosition,
                commandTarget: directive.commandTarget
            )
        default:
            return directive
        }
    }

    private func choosePreferredZoneId(snapshot: RulerStrategicSnapshot) -> FrontZoneId? {
        snapshot.zoneScores.sorted {
            if $0.value == $1.value {
                return $0.key.rawValue < $1.key.rawValue
            }
            return $0.value > $1.value
        }.first?.key
    }

    private func chooseTargetRegionIds(directives: [ZoneDirective], snapshot: RulerStrategicSnapshot) -> [RegionId] {
        let directed = directives.flatMap(\.targetRegionIds)
        if !directed.isEmpty {
            return stableUnique(directed).prefix(4).map { $0 }
        }
        return snapshot.contestedRegionIds.prefix(4).map { $0 }
    }

    private func prioritizedRegions(_ regions: [RegionId], snapshot: RulerStrategicSnapshot) -> [RegionId] {
        stableUnique(regions).sorted {
            let lhs = snapshot.regionPriority[$0, default: 0]
            let rhs = snapshot.regionPriority[$1, default: 0]
            return lhs == rhs ? $0.rawValue < $1.rawValue : lhs > rhs
        }
    }

    private func thresholdAdjustment(for posture: RulerStrategicPosture) -> Double {
        switch posture {
        case .offensive:
            return -0.15
        case .defensive:
            return 0.20
        case .coalitionMaintenance:
            return 0.05
        case .stabilizeFront:
            return 0.10
        }
    }

    private func reserveBias(for posture: RulerStrategicPosture) -> Int {
        switch posture {
        case .offensive:
            return 0
        case .defensive:
            return 2
        case .coalitionMaintenance:
            return 2
        case .stabilizeFront:
            return 1
        }
    }

    private func rationale(for posture: RulerStrategicPosture, snapshot: RulerStrategicSnapshot) -> String {
        switch posture {
        case .offensive:
            return "君主判断有利防区 \(snapshot.advantagedFrontZoneCount) 处，可承担进攻风险。"
        case .defensive:
            return "君主判断平均压力 \(snapshot.averageZonePressure)，兵力受压防区 \(snapshot.outnumberedFrontZoneCount) 处，应先守根本。"
        case .coalitionMaintenance:
            return "君主要求维系盟从与预备兵力，当前活跃防区 \(snapshot.frontZoneCount) 处。"
        case .stabilizeFront:
            return "君主要求先稳住边境争夺，避免军势过伸。"
        }
    }

    private func appendRulerContext(_ context: String?, record: RulerDecisionRecord) -> String {
        let targetText = record.preferredFrontZoneId == nil ? "暂无重点防区" : "已指定重点防区"
        let rulerContext = "君主决策：\(record.posture.displayName)，\(targetText)。"
        guard let context, !context.isEmpty else {
            return rulerContext
        }
        return "\(context) \(rulerContext)"
    }

    private func stableUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}

struct CourtDirectiveAdjustment: Equatable {
    let envelope: DirectiveEnvelope
    let rulerRecord: RulerDecisionRecord
    let courtRecord: CourtDecisionRecord
}

struct CourtAgent {
    func deliberate(
        envelope: DirectiveEnvelope,
        theaterEnvelope: TheaterDirectiveEnvelope?,
        in state: GameState
    ) -> CourtDirectiveAdjustment {
        let faction = theaterEnvelope?.faction ?? state.activeFaction
        let sovereign = RulerAgent.automatic(for: faction, in: state)
        let sovereignAdjustment = sovereign.adjust(envelope: envelope, in: state)
        let adjustedEnvelope = sovereignAdjustment.envelope
        let rulerRecord = sovereignAdjustment.record
        let strategistAgentId = theaterEnvelope?.issuerId
            ?? adjustedEnvelope.commanderAgentId
            ?? "strategist_\(faction.rawValue)"
        let marchAgentIds = stableUnique(
            adjustedEnvelope.directives.map { "march_commander_\($0.zoneId.rawValue)" }
        )
        let steps = makeSteps(
            envelope: adjustedEnvelope,
            theaterEnvelope: theaterEnvelope,
            rulerRecord: rulerRecord,
            strategistAgentId: strategistAgentId,
            marchAgentIds: marchAgentIds,
            state: state
        )
        let record = CourtDecisionRecord(
            id: "court_\(faction.rawValue)_turn_\(state.turn)",
            turn: state.turn,
            faction: faction,
            issuerId: adjustedEnvelope.issuerId,
            sovereignAgentId: rulerRecord.rulerAgentId,
            strategistAgentId: strategistAgentId,
            marchCommanderAgentIds: marchAgentIds,
            directiveCount: adjustedEnvelope.directives.count,
            rulerRecord: rulerRecord,
            steps: steps
        )

        return CourtDirectiveAdjustment(
            envelope: adjustedEnvelope,
            rulerRecord: rulerRecord,
            courtRecord: record
        )
    }

    private func makeSteps(
        envelope: DirectiveEnvelope,
        theaterEnvelope: TheaterDirectiveEnvelope?,
        rulerRecord: RulerDecisionRecord,
        strategistAgentId: String,
        marchAgentIds: [String],
        state: GameState
    ) -> [CourtAgentStepRecord] {
        let faction = rulerRecord.faction
        let targetZoneIds = stableUnique(envelope.directives.map(\.zoneId))
        let targetRegionIds = stableUnique(envelope.directives.flatMap(\.targetRegionIds))
        let governorRegions = governorFocusRegionIds(for: faction, in: state)
        let tacticNames = stableUnique(
            envelope.directives.compactMap { $0.tactic?.displayName }
        )

        return [
            CourtAgentStepRecord(
                id: "court_\(state.turn)_\(faction.rawValue)_sovereign",
                role: .sovereign,
                agentId: rulerRecord.rulerAgentId,
                summary: rulerRecord.posture.displayName,
                targetZoneIds: rulerRecord.preferredFrontZoneId.map { [$0] } ?? [],
                targetRegionIds: rulerRecord.targetRegionIds,
                directiveCount: envelope.directives.count,
                rationale: rulerRecord.rationale
            ),
            CourtAgentStepRecord(
                id: "court_\(state.turn)_\(faction.rawValue)_strategist",
                role: .strategist,
                agentId: strategistAgentId,
                summary: theaterEnvelope?.strategicIntent ?? envelope.theaterContext ?? "按当前战场态势生成方面目标",
                targetZoneIds: targetZoneIds,
                targetRegionIds: targetRegionIds,
                directiveCount: envelope.directives.count,
                rationale: theaterEnvelope?.summary ?? "谋主将战略意图编译为方面军令。"
            ),
            CourtAgentStepRecord(
                id: "court_\(state.turn)_\(faction.rawValue)_governor",
                role: .governor,
                agentId: "governor_staff_\(faction.rawValue)",
                summary: governorRegions.isEmpty ? "州郡后勤暂无紧急警报" : "关注 \(governorRegions.count) 个粮草/围城州郡",
                targetZoneIds: [],
                targetRegionIds: governorRegions,
                directiveCount: 0,
                rationale: "太守层只记录补给、围城和州郡治理风险，不直接执行状态修改。"
            ),
            CourtAgentStepRecord(
                id: "court_\(state.turn)_\(faction.rawValue)_march",
                role: .marchCommander,
                agentId: marchAgentIds.first ?? "march_commander_\(faction.rawValue)",
                summary: "下发 \(envelope.directives.count) 条方面军令",
                targetZoneIds: targetZoneIds,
                targetRegionIds: targetRegionIds,
                directiveCount: envelope.directives.count,
                rationale: "行军总管层只拟定方面军令，仍交由军令规则校验执行。"
            ),
            CourtAgentStepRecord(
                id: "court_\(state.turn)_\(faction.rawValue)_general",
                role: .general,
                agentId: "general_staff_\(faction.rawValue)",
                summary: tacticNames.isEmpty ? "未指定战术" : tacticNames.joined(separator: "、"),
                targetZoneIds: targetZoneIds,
                targetRegionIds: targetRegionIds,
                directiveCount: envelope.directives.count,
                rationale: "将领层影响战术偏好和投入节奏，不绕过底层命令校验。"
            ),
            CourtAgentStepRecord(
                id: "court_\(state.turn)_\(faction.rawValue)_diplomat",
                role: .diplomat,
                agentId: "diplomat_\(faction.rawValue)",
                summary: state.diplomacyState.summary(for: faction),
                targetZoneIds: [],
                targetRegionIds: [],
                directiveCount: 0,
                rationale: "使者层记录外交态势；自动轮转可在保守条件下提交停战或归附关系命令。"
            )
        ]
    }

    private func governorFocusRegionIds(for faction: Faction, in state: GameState) -> [RegionId] {
        let warningRegions = state.divisions.compactMap { division -> RegionId? in
            guard division.faction == faction,
                  !division.isDestroyed,
                  division.supplyState != .supplied else {
                return nil
            }
            return division.location(in: state.map)
        }
        let supplyRegions = state.map.regions.values
            .filter { $0.controller == faction && $0.supplyValue >= 3 }
            .map(\.id)
        return stableUnique(warningRegions + supplyRegions).prefix(5).map { $0 }
    }

    private func stableUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}

struct RulerStrategicSnapshot {
    let frontZoneCount: Int
    let averageZonePressure: Int
    let advantagedFrontZoneCount: Int
    let outnumberedFrontZoneCount: Int
    let contestedFriendlyPresenceCount: Int
    let hostileCountryCount: Int
    let staticDefenseStreak: Int
    let contestedRegionIds: [RegionId]
    let regionPriority: [RegionId: Int]
    let zoneScores: [FrontZoneId: Int]

    init(faction: Faction, state: GameState) {
        let zones = state.warDeploymentState.frontZones.values
            .filter { $0.faction == faction && !$0.frontSegments.isEmpty }
        frontZoneCount = zones.count
        averageZonePressure = zones.isEmpty ? 0 : zones.reduce(0) { $0 + $1.pressure } / zones.count
        hostileCountryCount = state.diplomacyState.hostileCountryIds(to: faction).count

        var advantaged = 0
        var outnumbered = 0
        var contestedPresence = 0
        var contestedRegions: [RegionId] = []
        var priorities: [RegionId: Int] = [:]
        var scores: [FrontZoneId: Int] = [:]

        for zone in zones {
            let friendlyStrength = Self.strength(for: zone.unitsFront + zone.unitsDepth, faction: faction, state: state)
            let enemyStrength = Self.enemyStrength(adjacentTo: zone, state: state)
            if friendlyStrength >= enemyStrength + 2 {
                advantaged += 1
            } else if enemyStrength > friendlyStrength {
                outnumbered += 1
            }

            let zoneScore = max(0, friendlyStrength - enemyStrength) + zone.pressure + zone.frontSegments.count
            scores[zone.id] = zoneScore

            for segment in zone.frontSegments {
                contestedRegions.append(segment.regionId)
                priorities[segment.regionId, default: 0] += zoneScore + segment.strength
                if segment.isEncircled {
                    priorities[segment.regionId, default: 0] += 6
                }
                if state.map.regions[segment.regionId]?.controller != faction {
                    contestedPresence += 1
                    priorities[segment.regionId, default: 0] += 4
                }
            }
        }

        advantagedFrontZoneCount = advantaged
        outnumberedFrontZoneCount = outnumbered
        contestedFriendlyPresenceCount = contestedPresence
        contestedRegionIds = Self.stableUnique(contestedRegions).sorted { $0.rawValue < $1.rawValue }
        regionPriority = priorities
        zoneScores = scores
        staticDefenseStreak = Self.staticDefenseStreak(for: faction, records: state.warDirectiveRecords)
    }

    private static func strength(for unitIds: [String], faction: Faction, state: GameState) -> Int {
        let ids = Set(unitIds)
        return state.divisions
            .filter { ids.contains($0.id) && $0.faction == faction && !$0.isDestroyed }
            .reduce(0) { $0 + max(1, $1.strength) + max(1, $1.attack) }
    }

    private static func enemyStrength(adjacentTo zone: FrontZone, state: GameState) -> Int {
        let visibleEnemyRegions = Set(zone.frontSegments.map(\.regionId))
        return state.divisions
            .filter { $0.faction != zone.faction && !$0.isDestroyed }
            .filter { division in
                guard let regionId = division.location(in: state.map) else {
                    return false
                }
                return visibleEnemyRegions.contains(regionId)
            }
            .reduce(0) { $0 + max(1, $1.strength) + max(1, $1.defense) }
    }

    private static func staticDefenseStreak(for faction: Faction, records: [WarDirectiveRecord]) -> Int {
        var streak = 0
        for record in records.reversed() where record.faction == faction {
            if record.directiveType == .defend {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private static func stableUnique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}

extension RulerAgent {
    static func automatic(for faction: Faction, in state: GameState) -> RulerAgent {
        let country = state.diplomacyState.primaryCountry(for: faction)
        let config: RulerAgentConfig
        switch faction {
        case .germany:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "ruler_germany",
                name: "旧剧本统帅",
                faction: faction,
                countryId: country?.id,
                aggression: 82,
                coalitionDiscipline: 45,
                riskTolerance: 68
            )
        case .allies:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "ruler_allies",
                name: "旧剧本议事会",
                faction: faction,
                countryId: country?.id,
                aggression: 58,
                coalitionDiscipline: 82,
                riskTolerance: 48
            )
        case .tang:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "sovereign_li_yuan",
                name: "李渊",
                faction: faction,
                countryId: country?.id,
                aggression: 68,
                coalitionDiscipline: 72,
                riskTolerance: 58
            )
        case .luoyangSui:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "sovereign_wang_shichong",
                name: "王世充",
                faction: faction,
                countryId: country?.id,
                aggression: 58,
                coalitionDiscipline: 46,
                riskTolerance: 52
            )
        case .wagang, .xia, .qinXue, .liuWuzhou, .tujue:
            config = RulerAgentConfig(
                id: country?.rulerAgentId ?? "sovereign_\(faction.rawValue)",
                name: "\(faction.displayName)君主",
                faction: faction,
                countryId: country?.id,
                aggression: 64,
                coalitionDiscipline: 55,
                riskTolerance: 60
            )
        }
        return RulerAgent(config: config)
    }
}
