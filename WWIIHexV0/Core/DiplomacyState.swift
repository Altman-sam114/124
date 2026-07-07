import Foundation

struct CountryId: Hashable, Codable, Equatable, RawRepresentable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    init(_ value: String) {
        self.rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct DiplomaticBlocId: Hashable, Codable, Equatable, RawRepresentable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    init(_ value: String) {
        self.rawValue = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum DiplomaticStatus: String, Codable, Equatable, CaseIterable {
    case allied
    case coBelligerent
    case neutral
    case truce
    case vassal
    case submitted
    case hostile
    case atWar

    var isHostile: Bool {
        self == .hostile || self == .atWar
    }

    var displayName: String {
        switch self {
        case .allied:
            return "盟友"
        case .coBelligerent:
            return "协同讨伐"
        case .neutral:
            return "中立"
        case .truce:
            return "停战"
        case .vassal:
            return "称臣"
        case .submitted:
            return "归附"
        case .hostile:
            return "敌对"
        case .atWar:
            return "交战"
        }
    }
}

struct CountryProfile: Identifiable, Codable, Equatable {
    let id: CountryId
    var name: String
    var faction: Faction
    var blocId: DiplomaticBlocId
    var rulerAgentId: String
    var isPrimaryBelligerent: Bool
    var capitalRegionId: RegionId?
    var surrenderProgress: Int
    var warSupport: Int

    init(
        id: CountryId,
        name: String,
        faction: Faction,
        blocId: DiplomaticBlocId,
        rulerAgentId: String,
        isPrimaryBelligerent: Bool = false,
        capitalRegionId: RegionId? = nil,
        surrenderProgress: Int = 0,
        warSupport: Int = 70
    ) {
        self.id = id
        self.name = name
        self.faction = faction
        self.blocId = blocId
        self.rulerAgentId = rulerAgentId
        self.isPrimaryBelligerent = isPrimaryBelligerent
        self.capitalRegionId = capitalRegionId
        self.surrenderProgress = max(0, min(100, surrenderProgress))
        self.warSupport = max(0, min(100, warSupport))
    }
}

struct DiplomaticBloc: Identifiable, Codable, Equatable {
    let id: DiplomaticBlocId
    var name: String
    var faction: Faction
    var memberCountryIds: [CountryId]

    init(id: DiplomaticBlocId, name: String, faction: Faction, memberCountryIds: [CountryId]) {
        self.id = id
        self.name = name
        self.faction = faction
        self.memberCountryIds = memberCountryIds.sorted { $0.rawValue < $1.rawValue }
    }
}

struct DiplomaticRelation: Identifiable, Codable, Equatable {
    let firstCountryId: CountryId
    let secondCountryId: CountryId
    var status: DiplomaticStatus
    var tension: Int
    var sinceTurn: Int

    var id: String {
        "\(firstCountryId.rawValue):\(secondCountryId.rawValue)"
    }

    init(
        firstCountryId: CountryId,
        secondCountryId: CountryId,
        status: DiplomaticStatus,
        tension: Int = 0,
        sinceTurn: Int = 1
    ) {
        if firstCountryId.rawValue <= secondCountryId.rawValue {
            self.firstCountryId = firstCountryId
            self.secondCountryId = secondCountryId
        } else {
            self.firstCountryId = secondCountryId
            self.secondCountryId = firstCountryId
        }
        self.status = status
        self.tension = max(0, min(100, tension))
        self.sinceTurn = max(1, sinceTurn)
    }

    func contains(_ countryId: CountryId) -> Bool {
        firstCountryId == countryId || secondCountryId == countryId
    }
}

struct DiplomacyEventRecord: Identifiable, Codable, Equatable {
    let id: String
    let turn: Int
    let issuer: Faction
    let target: Faction
    let status: DiplomaticStatus
    let issuerCountryIds: [CountryId]
    let targetCountryIds: [CountryId]
    let summary: String
    let boundaryNote: String
}

struct SubmissionHandoffRecord: Identifiable, Codable, Equatable {
    let id: String
    let turn: Int
    let submitted: Faction
    let recipient: Faction
    let transferredDivisionCount: Int
    let transferredHexCount: Int
    let affectedRegionIds: [RegionId]
    let summary: String
    let boundaryNote: String
}

enum SubmissionAftermathRiskLevel: String, Codable, Equatable, CaseIterable {
    case low
    case guarded
    case high

    var displayName: String {
        switch self {
        case .low:
            return "低"
        case .guarded:
            return "需安抚"
        case .high:
            return "高"
        }
    }
}

struct SubmissionAftermathRecord: Identifiable, Codable, Equatable {
    let id: String
    let turn: Int
    let submitted: Faction
    let recipient: Faction
    let linkedHandoffRecordId: String
    let riskLevel: SubmissionAftermathRiskLevel
    let transferredDivisionCount: Int
    let transferredHexCount: Int
    let affectedRegionIds: [RegionId]
    let summary: String
    let boundaryNote: String
}

struct SubmissionAftermathGovernanceRecord: Identifiable, Codable, Equatable {
    let id: String
    let turn: Int
    let faction: Faction
    let regionId: RegionId
    let regionName: String
    let policy: RegionGovernancePolicy
    let linkedAftermathRecordId: String
    let summary: String
    let boundaryNote: String
}

enum RulerStrategicPosture: String, Codable, Equatable, CaseIterable {
    case offensive
    case defensive
    case coalitionMaintenance
    case stabilizeFront

    var displayName: String {
        switch self {
        case .offensive:
            return "锐意进取"
        case .defensive:
            return "谨守根本"
        case .coalitionMaintenance:
            return "维系盟从"
        case .stabilizeFront:
            return "稳固战线"
        }
    }
}

struct RulerDecisionRecord: Identifiable, Codable, Equatable {
    let id: String
    let turn: Int
    let faction: Faction
    let countryId: CountryId?
    let rulerAgentId: String
    let posture: RulerStrategicPosture
    let preferredFrontZoneId: FrontZoneId?
    let targetRegionIds: [RegionId]
    let attackThresholdAdjustment: Double
    let reserveBias: Int
    let diplomacySummary: String
    let rationale: String
}

enum CourtAgentRole: String, Codable, Equatable, CaseIterable {
    case sovereign
    case strategist
    case governor
    case marchCommander
    case general
    case diplomat

    var displayName: String {
        switch self {
        case .sovereign:
            return "君主"
        case .strategist:
            return "谋主"
        case .governor:
            return "太守"
        case .marchCommander:
            return "行军总管"
        case .general:
            return "将领"
        case .diplomat:
            return "使者"
        }
    }
}

struct CourtAgentStepRecord: Identifiable, Codable, Equatable {
    let id: String
    let role: CourtAgentRole
    let agentId: String
    let summary: String
    let targetZoneIds: [FrontZoneId]
    let targetRegionIds: [RegionId]
    let directiveCount: Int
    let rationale: String
}

struct CourtDecisionRecord: Identifiable, Codable, Equatable {
    let id: String
    let turn: Int
    let faction: Faction
    let issuerId: String
    let sovereignAgentId: String
    let strategistAgentId: String
    let marchCommanderAgentIds: [String]
    let directiveCount: Int
    let rulerRecord: RulerDecisionRecord
    let steps: [CourtAgentStepRecord]

    var summary: String {
        let stepText = steps
            .map { "\($0.role.displayName): \($0.summary)" }
            .joined(separator: " / ")
        return stepText.isEmpty ? rulerRecord.rationale : stepText
    }
}

struct DiplomacyState: Codable, Equatable {
    var countries: [CountryProfile]
    var blocs: [DiplomaticBloc]
    var relations: [DiplomaticRelation]
    var rulerRecords: [RulerDecisionRecord]
    var courtRecords: [CourtDecisionRecord]
    var diplomacyEventRecords: [DiplomacyEventRecord]
    var submissionHandoffRecords: [SubmissionHandoffRecord]
    var submissionAftermathRecords: [SubmissionAftermathRecord]
    var submissionAftermathGovernanceRecords: [SubmissionAftermathGovernanceRecord]
    var lastUpdatedTurn: Int?

    init(
        countries: [CountryProfile] = [],
        blocs: [DiplomaticBloc] = [],
        relations: [DiplomaticRelation] = [],
        rulerRecords: [RulerDecisionRecord] = [],
        courtRecords: [CourtDecisionRecord] = [],
        diplomacyEventRecords: [DiplomacyEventRecord] = [],
        submissionHandoffRecords: [SubmissionHandoffRecord] = [],
        submissionAftermathRecords: [SubmissionAftermathRecord] = [],
        submissionAftermathGovernanceRecords: [SubmissionAftermathGovernanceRecord] = [],
        lastUpdatedTurn: Int? = nil
    ) {
        self.countries = countries.sorted { $0.id.rawValue < $1.id.rawValue }
        self.blocs = blocs.sorted { $0.id.rawValue < $1.id.rawValue }
        self.relations = relations.sorted { $0.id < $1.id }
        self.rulerRecords = rulerRecords
        self.courtRecords = courtRecords
        self.diplomacyEventRecords = diplomacyEventRecords
        self.submissionHandoffRecords = submissionHandoffRecords
        self.submissionAftermathRecords = submissionAftermathRecords
        self.submissionAftermathGovernanceRecords = submissionAftermathGovernanceRecords
        self.lastUpdatedTurn = lastUpdatedTurn
    }

    static var empty: DiplomacyState {
        DiplomacyState()
    }

    static func initial(for factions: [Faction], turn: Int) -> DiplomacyState {
        var countries: [CountryProfile] = []
        var blocs: [DiplomaticBloc] = []
        let resolvedFactions = stableFactions(factions.isEmpty ? Faction.legacyCombatants : factions)

        for faction in resolvedFactions {
            let profiles = initialCountryProfiles(for: faction)
            countries.append(contentsOf: profiles)
            blocs.append(
                DiplomaticBloc(
                    id: defaultBlocId(for: faction),
                    name: defaultBlocName(for: faction),
                    faction: faction,
                    memberCountryIds: profiles.map(\.id)
                )
            )
        }

        return DiplomacyState(
            countries: countries,
            blocs: blocs,
            relations: makeInitialRelations(countries: countries, turn: turn),
            lastUpdatedTurn: turn
        )
    }

    static func initial(from factionStrings: [String], turn: Int) -> DiplomacyState {
        let factions = factionStrings.compactMap(Faction.init(rawValue:))
        return initial(for: factions.isEmpty ? Faction.legacyCombatants : factions, turn: turn)
    }

    var latestRulerRecord: RulerDecisionRecord? {
        rulerRecords.last
    }

    var latestCourtRecord: CourtDecisionRecord? {
        courtRecords.last
    }

    var latestDiplomacyEventRecord: DiplomacyEventRecord? {
        diplomacyEventRecords.last
    }

    var latestSubmissionHandoffRecord: SubmissionHandoffRecord? {
        submissionHandoffRecords.last
    }

    var latestSubmissionAftermathRecord: SubmissionAftermathRecord? {
        submissionAftermathRecords.last
    }

    var latestSubmissionAftermathGovernanceRecord: SubmissionAftermathGovernanceRecord? {
        submissionAftermathGovernanceRecords.last
    }

    func submissionAftermathGovernanceRecords(linkedTo aftermathRecordId: String) -> [SubmissionAftermathGovernanceRecord] {
        submissionAftermathGovernanceRecords.filter { $0.linkedAftermathRecordId == aftermathRecordId }
    }

    func governedAftermathRegionCount(linkedTo aftermathRecordId: String, affectedRegionIds: [RegionId]) -> Int {
        governedAftermathRegionIds(linkedTo: aftermathRecordId, affectedRegionIds: affectedRegionIds).count
    }

    func ungovernedAftermathRegionCount(linkedTo aftermathRecordId: String, affectedRegionIds: [RegionId]) -> Int {
        ungovernedAftermathRegionIds(linkedTo: aftermathRecordId, affectedRegionIds: affectedRegionIds).count
    }

    func isAftermathGovernanceComplete(linkedTo aftermathRecordId: String, affectedRegionIds: [RegionId]) -> Bool {
        !affectedRegionIds.isEmpty &&
            ungovernedAftermathRegionIds(linkedTo: aftermathRecordId, affectedRegionIds: affectedRegionIds).isEmpty
    }

    func governedAftermathRegionIds(linkedTo aftermathRecordId: String, affectedRegionIds: [RegionId]) -> [RegionId] {
        let governedRegionIds = Set(
            submissionAftermathGovernanceRecords(linkedTo: aftermathRecordId).map(\.regionId)
        )
        return affectedRegionIds.filter { governedRegionIds.contains($0) }
    }

    func ungovernedAftermathRegionIds(linkedTo aftermathRecordId: String, affectedRegionIds: [RegionId]) -> [RegionId] {
        let governedRegionIds = Set(
            submissionAftermathGovernanceRecords(linkedTo: aftermathRecordId).map(\.regionId)
        )
        return affectedRegionIds.filter { !governedRegionIds.contains($0) }
    }

    func countries(for faction: Faction) -> [CountryProfile] {
        countries.filter { $0.faction == faction }
    }

    func primaryCountry(for faction: Faction) -> CountryProfile? {
        countries(for: faction).first(where: \.isPrimaryBelligerent) ?? countries(for: faction).first
    }

    func relation(between lhs: CountryId, and rhs: CountryId) -> DiplomaticRelation? {
        let key = DiplomaticRelation(firstCountryId: lhs, secondCountryId: rhs, status: .neutral).id
        return relations.first { $0.id == key }
    }

    func relationStatus(between lhs: Faction, and rhs: Faction) -> DiplomaticStatus {
        guard lhs != rhs else {
            return .allied
        }

        let lhsCountries = countries(for: lhs)
        let rhsCountries = countries(for: rhs)
        guard !lhsCountries.isEmpty, !rhsCountries.isEmpty else {
            return .atWar
        }

        let statuses = lhsCountries.flatMap { lhsCountry in
            rhsCountries.compactMap { rhsCountry in
                relation(between: lhsCountry.id, and: rhsCountry.id)?.status
            }
        }

        if statuses.contains(.atWar) {
            return .atWar
        }
        if statuses.contains(.hostile) {
            return .hostile
        }
        if statuses.contains(.truce) {
            return .truce
        }
        if statuses.contains(.neutral) || statuses.isEmpty {
            return .neutral
        }
        if statuses.contains(.vassal) {
            return .vassal
        }
        if statuses.contains(.submitted) {
            return .submitted
        }
        return .allied
    }

    func isHostile(_ lhs: Faction, _ rhs: Faction) -> Bool {
        guard lhs != rhs else {
            return false
        }
        return relationStatus(between: lhs, and: rhs).isHostile
    }

    func canAttack(_ lhs: Faction, _ rhs: Faction) -> Bool {
        isHostile(lhs, rhs)
    }

    func isFriendly(_ lhs: Faction, _ rhs: Faction) -> Bool {
        guard lhs != rhs else {
            return true
        }
        let status = relationStatus(between: lhs, and: rhs)
        return status == .allied || status == .coBelligerent || status == .vassal || status == .submitted
    }

    func isSubmittedTarget(_ faction: Faction) -> Bool {
        if !diplomacyEventRecords.isEmpty {
            return latestDiplomacyEventByTarget[faction]?.status == .submitted
        }

        let countryIds = Set(countries(for: faction).map(\.id))
        guard !countryIds.isEmpty else {
            return false
        }

        return relations.contains { relation in
            relation.status == .submitted &&
                (countryIds.contains(relation.firstCountryId) || countryIds.contains(relation.secondCountryId))
        }
    }

    func submittedTargetFactions() -> [Faction] {
        let targets: Set<Faction>
        if !diplomacyEventRecords.isEmpty {
            targets = Set(
                latestDiplomacyEventByTarget.values
                    .filter { $0.status == .submitted }
                    .map(\.target)
            )
        } else {
            var countryFactionById: [CountryId: Faction] = [:]
            for country in countries {
                countryFactionById[country.id] = country.faction
            }
            targets = Set(
                relations
                    .filter { $0.status == .submitted }
                    .flatMap { relation in
                        [relation.firstCountryId, relation.secondCountryId].compactMap { countryFactionById[$0] }
                    }
            )
        }

        let preferred = Faction.suitangTurnOrder + Faction.legacyCombatants
        let ordered = preferred.filter { targets.contains($0) }
        let remaining = targets
            .subtracting(Set(preferred))
            .sorted { $0.rawValue < $1.rawValue }
        return ordered + remaining
    }

    func submissionRecipient(for submitted: Faction) -> Faction? {
        guard let record = latestDiplomacyEventByTarget[submitted],
              record.status == .submitted else {
            return nil
        }
        return record.issuer
    }

    func canResolveSubmissionHandoff(submitted: Faction, recipient: Faction) -> Bool {
        guard submitted != recipient else {
            return false
        }

        if let eventRecipient = submissionRecipient(for: submitted) {
            return eventRecipient == recipient
        }

        return relationStatus(between: recipient, and: submitted) == .submitted
    }

    func hostileCountryIds(to faction: Faction) -> [CountryId] {
        let ownCountryIds = Set(countries(for: faction).map(\.id))
        var hostileCountryIds: Set<CountryId> = []
        for relation in relations where relation.status.isHostile {
            let touchesOwnCountry = ownCountryIds.contains(relation.firstCountryId) ||
                ownCountryIds.contains(relation.secondCountryId)
            guard touchesOwnCountry else {
                continue
            }
            if !ownCountryIds.contains(relation.firstCountryId) {
                hostileCountryIds.insert(relation.firstCountryId)
            }
            if !ownCountryIds.contains(relation.secondCountryId) {
                hostileCountryIds.insert(relation.secondCountryId)
            }
        }
        return hostileCountryIds.sorted { $0.rawValue < $1.rawValue }
    }

    private var latestDiplomacyEventByTarget: [Faction: DiplomacyEventRecord] {
        var recordsByTarget: [Faction: DiplomacyEventRecord] = [:]
        for record in diplomacyEventRecords {
            recordsByTarget[record.target] = record
        }
        return recordsByTarget
    }

    func summary(for faction: Faction) -> String {
        let countryNames = countries(for: faction)
            .map { displayCountryName($0.name) }
            .joined(separator: "、")
        let hostileCount = hostileCountryIds(to: faction).count
        return "\(displayFactionName(faction))：\(countryNames.isEmpty ? "无国家档案" : countryNames)；敌对国家 \(hostileCount) 个。"
    }

    private func displayFactionName(_ faction: Faction) -> String {
        switch faction {
        case .germany, .allies:
            return "旧剧本势力"
        default:
            return faction.displayName
        }
    }

    private func displayCountryName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "旧剧本德方", with: "旧剧本国家")
            .replacingOccurrences(of: "旧剧本美方", with: "旧剧本国家")
            .replacingOccurrences(of: "旧剧本英方", with: "旧剧本国家")
            .replacingOccurrences(of: "Germany", with: "旧剧本国家")
            .replacingOccurrences(of: "Allies", with: "旧剧本国家")
            .replacingOccurrences(of: "German", with: "旧剧本国家")
            .replacingOccurrences(of: "United States", with: "旧剧本国家")
            .replacingOccurrences(of: "United Kingdom", with: "旧剧本国家")
            .replacingOccurrences(of: "France", with: "旧剧本国家")
    }

    mutating func appendRulerRecord(_ record: RulerDecisionRecord) {
        rulerRecords.append(record)
        if rulerRecords.count > 40 {
            rulerRecords.removeFirst(rulerRecords.count - 40)
        }
        lastUpdatedTurn = record.turn
    }

    mutating func appendCourtRecord(_ record: CourtDecisionRecord) {
        courtRecords.append(record)
        if courtRecords.count > 40 {
            courtRecords.removeFirst(courtRecords.count - 40)
        }
        lastUpdatedTurn = record.turn
    }

    mutating func updateRelation(
        issuer: Faction,
        target: Faction,
        status: DiplomaticStatus,
        turn: Int
    ) {
        let issuerCountries = countries(for: issuer)
        let targetCountries = countries(for: target)
        guard !issuerCountries.isEmpty, !targetCountries.isEmpty else {
            return
        }

        for issuerCountry in issuerCountries {
            for targetCountry in targetCountries {
                setRelation(
                    between: issuerCountry.id,
                    and: targetCountry.id,
                    status: status,
                    turn: turn
                )
            }
        }
        relations.sort { $0.id < $1.id }
        lastUpdatedTurn = turn
    }

    mutating func appendDiplomacyEventRecord(
        issuer: Faction,
        target: Faction,
        status: DiplomaticStatus,
        turn: Int
    ) -> DiplomacyEventRecord? {
        let issuerCountries = countries(for: issuer)
        let targetCountries = countries(for: target)
        guard !issuerCountries.isEmpty, !targetCountries.isEmpty else {
            return nil
        }

        let recordIndex = diplomacyEventRecords.count + 1
        let record = DiplomacyEventRecord(
            id: "diplomacy_\(turn)_\(recordIndex)_\(issuer.rawValue)_\(target.rawValue)_\(status.rawValue)",
            turn: turn,
            issuer: issuer,
            target: target,
            status: status,
            issuerCountryIds: issuerCountries.map(\.id).sorted { $0.rawValue < $1.rawValue },
            targetCountryIds: targetCountries.map(\.id).sorted { $0.rawValue < $1.rawValue },
            summary: diplomacyEventSummary(issuer: issuer, target: target, status: status),
            boundaryNote: diplomacyEventBoundaryNote(status: status)
        )
        diplomacyEventRecords.append(record)
        if diplomacyEventRecords.count > 80 {
            diplomacyEventRecords.removeFirst(diplomacyEventRecords.count - 80)
        }
        lastUpdatedTurn = turn
        return record
    }

    mutating func appendSubmissionHandoffRecord(
        submitted: Faction,
        recipient: Faction,
        transferredDivisionCount: Int,
        transferredHexCount: Int,
        affectedRegionIds: [RegionId],
        turn: Int
    ) -> SubmissionHandoffRecord {
        let sortedRegionIds = affectedRegionIds.sorted { $0.rawValue < $1.rawValue }
        let recordIndex = submissionHandoffRecords.count + 1
        let record = SubmissionHandoffRecord(
            id: "submission_handoff_\(turn)_\(recordIndex)_\(submitted.rawValue)_\(recipient.rawValue)",
            turn: turn,
            submitted: submitted,
            recipient: recipient,
            transferredDivisionCount: max(0, transferredDivisionCount),
            transferredHexCount: max(0, transferredHexCount),
            affectedRegionIds: sortedRegionIds,
            summary: "\(displayFactionName(recipient)) 接管 \(displayFactionName(submitted))：军队 \(max(0, transferredDivisionCount))，地块 \(max(0, transferredHexCount))",
            boundaryNote: "交接记录只审计已完成的归属转移，不删除外交档案，不处理忠诚、叛乱、贡赋、俘虏或安置。"
        )
        submissionHandoffRecords.append(record)
        if submissionHandoffRecords.count > 80 {
            submissionHandoffRecords.removeFirst(submissionHandoffRecords.count - 80)
        }
        lastUpdatedTurn = turn
        return record
    }

    mutating func appendSubmissionAftermathRecord(
        submitted: Faction,
        recipient: Faction,
        transferredDivisionCount: Int,
        transferredHexCount: Int,
        affectedRegionIds: [RegionId],
        linkedHandoffRecordId: String,
        turn: Int
    ) -> SubmissionAftermathRecord {
        let sortedRegionIds = affectedRegionIds.sorted { $0.rawValue < $1.rawValue }
        let riskLevel = submissionAftermathRiskLevel(
            transferredDivisionCount: transferredDivisionCount,
            transferredHexCount: transferredHexCount,
            affectedRegionCount: sortedRegionIds.count
        )
        let recordIndex = submissionAftermathRecords.count + 1
        let record = SubmissionAftermathRecord(
            id: "submission_aftermath_\(turn)_\(recordIndex)_\(submitted.rawValue)_\(recipient.rawValue)",
            turn: turn,
            submitted: submitted,
            recipient: recipient,
            linkedHandoffRecordId: linkedHandoffRecordId,
            riskLevel: riskLevel,
            transferredDivisionCount: max(0, transferredDivisionCount),
            transferredHexCount: max(0, transferredHexCount),
            affectedRegionIds: sortedRegionIds,
            summary: submissionAftermathSummary(
                submitted: submitted,
                recipient: recipient,
                riskLevel: riskLevel,
                transferredDivisionCount: transferredDivisionCount,
                transferredHexCount: transferredHexCount,
                affectedRegionCount: sortedRegionIds.count
            ),
            boundaryNote: "善后压力会写入受影响州郡的治安/顺从压力，用于提示后续安民、整军或道路粮仓治理优先级；不触发叛乱、忠诚、贡赋、俘虏、资源扣减或额外归属转移。"
        )
        submissionAftermathRecords.append(record)
        if submissionAftermathRecords.count > 80 {
            submissionAftermathRecords.removeFirst(submissionAftermathRecords.count - 80)
        }
        lastUpdatedTurn = turn
        return record
    }

    mutating func appendSubmissionAftermathGovernanceRecord(
        faction: Faction,
        regionId: RegionId,
        regionName: String,
        policy: RegionGovernancePolicy,
        linkedAftermathRecordId: String,
        turn: Int
    ) -> SubmissionAftermathGovernanceRecord {
        let recordIndex = submissionAftermathGovernanceRecords.count + 1
        let record = SubmissionAftermathGovernanceRecord(
            id: "submission_aftermath_governance_\(turn)_\(recordIndex)_\(faction.rawValue)_\(regionId.rawValue)_\(policy.rawValue)",
            turn: turn,
            faction: faction,
            regionId: regionId,
            regionName: regionName,
            policy: policy,
            linkedAftermathRecordId: linkedAftermathRecordId,
            summary: "\(displayFactionName(faction)) 善后处置：\(regionName) \(policy.displayName)",
            boundaryNote: "善后处置记录关联既有州郡经营命令；安民等政策通过州郡经营调整治安/顺从，但不删除善后压力记录，不触发忠诚、叛乱、贡赋、俘虏、安置或额外资源变化。"
        )
        submissionAftermathGovernanceRecords.append(record)
        if submissionAftermathGovernanceRecords.count > 80 {
            submissionAftermathGovernanceRecords.removeFirst(submissionAftermathGovernanceRecords.count - 80)
        }
        lastUpdatedTurn = turn
        return record
    }

    private enum CodingKeys: String, CodingKey {
        case countries
        case blocs
        case relations
        case rulerRecords
        case courtRecords
        case diplomacyEventRecords
        case submissionHandoffRecords
        case submissionAftermathRecords
        case submissionAftermathGovernanceRecords
        case lastUpdatedTurn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            countries: try container.decodeIfPresent([CountryProfile].self, forKey: .countries) ?? [],
            blocs: try container.decodeIfPresent([DiplomaticBloc].self, forKey: .blocs) ?? [],
            relations: try container.decodeIfPresent([DiplomaticRelation].self, forKey: .relations) ?? [],
            rulerRecords: try container.decodeIfPresent([RulerDecisionRecord].self, forKey: .rulerRecords) ?? [],
            courtRecords: try container.decodeIfPresent([CourtDecisionRecord].self, forKey: .courtRecords) ?? [],
            diplomacyEventRecords: try container.decodeIfPresent(
                [DiplomacyEventRecord].self,
                forKey: .diplomacyEventRecords
            ) ?? [],
            submissionHandoffRecords: try container.decodeIfPresent(
                [SubmissionHandoffRecord].self,
                forKey: .submissionHandoffRecords
            ) ?? [],
            submissionAftermathRecords: try container.decodeIfPresent(
                [SubmissionAftermathRecord].self,
                forKey: .submissionAftermathRecords
            ) ?? [],
            submissionAftermathGovernanceRecords: try container.decodeIfPresent(
                [SubmissionAftermathGovernanceRecord].self,
                forKey: .submissionAftermathGovernanceRecords
            ) ?? [],
            lastUpdatedTurn: try container.decodeIfPresent(Int.self, forKey: .lastUpdatedTurn)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(countries, forKey: .countries)
        try container.encode(blocs, forKey: .blocs)
        try container.encode(relations, forKey: .relations)
        try container.encode(rulerRecords, forKey: .rulerRecords)
        try container.encode(courtRecords, forKey: .courtRecords)
        try container.encode(diplomacyEventRecords, forKey: .diplomacyEventRecords)
        try container.encode(submissionHandoffRecords, forKey: .submissionHandoffRecords)
        try container.encode(submissionAftermathRecords, forKey: .submissionAftermathRecords)
        try container.encode(submissionAftermathGovernanceRecords, forKey: .submissionAftermathGovernanceRecords)
        try container.encodeIfPresent(lastUpdatedTurn, forKey: .lastUpdatedTurn)
    }

    private static func makeInitialRelations(countries: [CountryProfile], turn: Int) -> [DiplomaticRelation] {
        var relations: [DiplomaticRelation] = []
        for lhsIndex in countries.indices {
            for rhsIndex in countries.indices where rhsIndex > lhsIndex {
                let lhs = countries[lhsIndex]
                let rhs = countries[rhsIndex]
                let status: DiplomaticStatus = lhs.faction == rhs.faction ? .allied : .atWar
                relations.append(
                    DiplomaticRelation(
                        firstCountryId: lhs.id,
                        secondCountryId: rhs.id,
                        status: status,
                        tension: status == .atWar ? 100 : 10,
                        sinceTurn: turn
                    )
                )
            }
        }
        return relations
    }

    private mutating func setRelation(
        between lhs: CountryId,
        and rhs: CountryId,
        status: DiplomaticStatus,
        turn: Int
    ) {
        let updatedRelation = DiplomaticRelation(
            firstCountryId: lhs,
            secondCountryId: rhs,
            status: status,
            tension: tension(for: status),
            sinceTurn: turn
        )
        if let index = relations.firstIndex(where: { $0.id == updatedRelation.id }) {
            relations[index] = updatedRelation
        } else {
            relations.append(updatedRelation)
        }
    }

    private func tension(for status: DiplomaticStatus) -> Int {
        switch status {
        case .atWar:
            return 100
        case .hostile:
            return 85
        case .neutral:
            return 45
        case .truce:
            return 20
        case .coBelligerent:
            return 15
        case .allied, .vassal, .submitted:
            return 10
        }
    }

    private func submissionAftermathRiskLevel(
        transferredDivisionCount: Int,
        transferredHexCount: Int,
        affectedRegionCount: Int
    ) -> SubmissionAftermathRiskLevel {
        var score = 0
        if transferredDivisionCount > 0 {
            score += min(3, transferredDivisionCount)
        }

        if transferredHexCount >= 6 {
            score += 3
        } else if transferredHexCount >= 3 {
            score += 2
        } else if transferredHexCount > 0 {
            score += 1
        }

        if affectedRegionCount >= 3 {
            score += 2
        } else if affectedRegionCount > 0 {
            score += 1
        }

        if score >= 5 {
            return .high
        }
        if score >= 2 {
            return .guarded
        }
        return .low
    }

    private func submissionAftermathSummary(
        submitted: Faction,
        recipient: Faction,
        riskLevel: SubmissionAftermathRiskLevel,
        transferredDivisionCount: Int,
        transferredHexCount: Int,
        affectedRegionCount: Int
    ) -> String {
        "\(displayFactionName(recipient)) 接收 \(displayFactionName(submitted)) 后善后压力 \(riskLevel.displayName)：军队 \(max(0, transferredDivisionCount))，地块 \(max(0, transferredHexCount))，州郡 \(max(0, affectedRegionCount))"
    }

    private func diplomacyEventSummary(issuer: Faction, target: Faction, status: DiplomaticStatus) -> String {
        let issuerName = displayFactionName(issuer)
        let targetName = displayFactionName(target)
        switch status {
        case .allied:
            return "\(issuerName) 与 \(targetName) 缔结盟约"
        case .coBelligerent:
            return "\(issuerName) 与 \(targetName) 协同讨伐"
        case .neutral:
            return "\(issuerName) 与 \(targetName) 恢复中立"
        case .truce:
            return "\(issuerName) 与 \(targetName) 议定停战"
        case .vassal:
            return "\(targetName) 向 \(issuerName) 称臣"
        case .submitted:
            return "\(targetName) 归附 \(issuerName)"
        case .hostile:
            return "\(issuerName) 与 \(targetName) 转为敌对"
        case .atWar:
            return "\(issuerName) 对 \(targetName) 宣战"
        }
    }

    private func diplomacyEventBoundaryNote(status: DiplomaticStatus) -> String {
        switch status {
        case .submitted:
            return "归附事件当前只记录关系结果，不转移地块、州郡、军队、当前方面、前线或部署归属。"
        case .truce:
            return "停战事件当前只记录关系结果，不撤销已存在的战术占领或军队位置。"
        default:
            return "外交事件当前只记录关系结果，不直接修改战术权威状态。"
        }
    }

    private static func stableFactions(_ factions: [Faction]) -> [Faction] {
        let unique = Set(factions)
        let preferred = Faction.legacyCombatants + Faction.suitangTurnOrder
        let ordered = preferred.filter { unique.contains($0) }
        let remaining = unique
            .subtracting(Set(preferred))
            .sorted { $0.rawValue < $1.rawValue }
        return ordered + remaining
    }

    private static func defaultBlocId(for faction: Faction) -> DiplomaticBlocId {
        switch faction {
        case .germany:
            return "axis"
        case .allies:
            return "allied_coalition"
        case .tang:
            return "bloc_tang"
        case .luoyangSui:
            return "bloc_luoyang_sui"
        case .wagang:
            return "bloc_wagang"
        case .xia:
            return "bloc_xia"
        case .qinXue:
            return "bloc_qin_xue"
        case .liuWuzhou:
            return "bloc_liu_wuzhou"
        case .tujue:
            return "bloc_tujue"
        }
    }

    private static func defaultBlocName(for faction: Faction) -> String {
        switch faction {
        case .germany:
            return "旧剧本轴心"
        case .allies:
            return "旧剧本盟从"
        default:
            return faction.displayName
        }
    }

    private static func initialCountryProfiles(for faction: Faction) -> [CountryProfile] {
        let blocId = defaultBlocId(for: faction)
        switch faction {
        case .germany:
            return [
                CountryProfile(
                    id: "germany",
                    name: "旧剧本德方",
                    faction: .germany,
                    blocId: blocId,
                    rulerAgentId: "ruler_germany",
                    isPrimaryBelligerent: true,
                    warSupport: 82
                )
            ]
        case .allies:
            return [
                CountryProfile(
                    id: "united_states",
                    name: "旧剧本美方",
                    faction: .allies,
                    blocId: blocId,
                    rulerAgentId: "ruler_allies",
                    isPrimaryBelligerent: true,
                    warSupport: 78
                ),
                CountryProfile(
                    id: "united_kingdom",
                    name: "旧剧本英方",
                    faction: .allies,
                    blocId: blocId,
                    rulerAgentId: "ruler_uk",
                    warSupport: 74
                ),
                CountryProfile(
                    id: "belgium",
                    name: "旧剧本地方盟友",
                    faction: .allies,
                    blocId: blocId,
                    rulerAgentId: "ruler_belgium",
                    warSupport: 68
                )
            ]
        case .tang:
            return [CountryProfile(id: "power_tang", name: "唐", faction: faction, blocId: blocId, rulerAgentId: "sovereign_li_yuan", isPrimaryBelligerent: true, warSupport: 76)]
        case .luoyangSui:
            return [CountryProfile(id: "power_luoyang_sui", name: "洛阳隋", faction: faction, blocId: blocId, rulerAgentId: "sovereign_wang_shichong", isPrimaryBelligerent: true, warSupport: 68)]
        case .wagang:
            return [CountryProfile(id: "power_wagang", name: "瓦岗", faction: faction, blocId: blocId, rulerAgentId: "sovereign_li_mi", isPrimaryBelligerent: true, warSupport: 70)]
        case .xia:
            return [CountryProfile(id: "power_xia", name: "夏", faction: faction, blocId: blocId, rulerAgentId: "sovereign_dou_jiande", isPrimaryBelligerent: true, warSupport: 72)]
        case .qinXue:
            return [CountryProfile(id: "power_qin_xue", name: "薛秦", faction: faction, blocId: blocId, rulerAgentId: "sovereign_xue_ju", isPrimaryBelligerent: true, warSupport: 66)]
        case .liuWuzhou:
            return [CountryProfile(id: "power_liu_wuzhou", name: "刘武周", faction: faction, blocId: blocId, rulerAgentId: "sovereign_liu_wuzhou", isPrimaryBelligerent: true, warSupport: 64)]
        case .tujue:
            return [CountryProfile(id: "power_tujue", name: "东突厥", faction: faction, blocId: blocId, rulerAgentId: "sovereign_tujue", isPrimaryBelligerent: true, warSupport: 60)]
        }
    }
}
