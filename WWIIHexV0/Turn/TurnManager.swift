import Foundation

// TurnManager orchestrates AI turns. It does not implement rules.
// Builds context -> provider -> JSON -> parser -> mapper -> RuleEngine -> record.

struct AgentTurnOutcome: Equatable {
    let state: GameState
    let record: AgentDecisionRecord
    let directiveRecords: [WarDirectiveRecord]

    init(
        state: GameState,
        record: AgentDecisionRecord,
        directiveRecords: [WarDirectiveRecord] = []
    ) {
        self.state = state
        self.record = record
        self.directiveRecords = directiveRecords
    }
}

private struct GovernorCommandExecution: Equatable {
    let state: GameState
    let commandResults: [CommandResultSummary]
    let diagnostics: [String]
}

private struct DiplomatCommandExecution: Equatable {
    let state: GameState
    let commandResults: [CommandResultSummary]
    let diagnostics: [String]
}

private struct SubmissionHandoffCommandExecution: Equatable {
    let state: GameState
    let commandResults: [CommandResultSummary]
    let diagnostics: [String]
}

struct TurnManager {
    let agent: GameAgent
    let provider: DecisionProvider
    let providerName: String
    let commandHandler: GameCommandHandling
    let contextBuilder: AgentContextBuilder
    let parser: AgentDecisionParser
    let mapper: AgentCommandMapper
    let commanderPool: TheaterCommanderPool?
    let marshalAgent: MarshalAgent?
    let warCommandExecutor: WarCommandExecutor

    init(
        agent: GameAgent,
        provider: DecisionProvider,
        providerName: String,
        commandHandler: GameCommandHandling,
        contextBuilder: AgentContextBuilder = AgentContextBuilder(),
        parser: AgentDecisionParser = AgentDecisionParser(),
        mapper: AgentCommandMapper = AgentCommandMapper(),
        commanderPool: TheaterCommanderPool? = nil,
        marshalAgent: MarshalAgent? = nil,
        warCommandExecutor: WarCommandExecutor? = nil
    ) {
        self.agent = agent
        self.provider = provider
        self.providerName = providerName
        self.commandHandler = commandHandler
        self.contextBuilder = contextBuilder
        self.parser = parser
        self.mapper = mapper
        self.commanderPool = commanderPool
        self.marshalAgent = marshalAgent
        self.warCommandExecutor = warCommandExecutor ?? WarCommandExecutor(commandHandler: commandHandler)
    }

    func runGermanAITurn(
        state: GameState,
        pipelineMode: WarPipelineMode = .marshalDirective
    ) async -> AgentTurnOutcome {
        await runAITurn(state: state, faction: .germany, pipelineMode: pipelineMode)
    }

    func runAITurn(
        state: GameState,
        faction: Faction,
        pipelineMode: WarPipelineMode = .marshalDirective
    ) async -> AgentTurnOutcome {
        let context = contextBuilder.agentContext(for: agent, state: state, playerDirective: nil)
        let contextSummary = Self.contextSummary(context)

        guard agent.faction == faction else {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: ["无法执行 \(faction.displayName) 的自动回合：当前总管属于 \(agent.faction.displayName)。"]
                )
            )
        }

        guard isAITurn(faction: faction, state: state) else {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: ["\(faction.displayName) 当前不在可自动行动阶段。"]
                )
            )
        }

        switch pipelineMode {
        case .marshalDirective:
            return runMarshalDirectiveTurn(
                state: state,
                faction: faction,
                contextSummary: contextSummary
            )
        case .zoneDirective:
            return runDirectiveTurn(
                state: state,
                faction: faction,
                contextSummary: contextSummary
            )
        case .legacyAgentOrder:
            return await runLegacyAgentOrderTurn(state: state, context: context, contextSummary: contextSummary)
        }
    }

    private func runLegacyAgentOrderTurn(
        state: GameState,
        context: AgentContext,
        contextSummary: String
    ) async -> AgentTurnOutcome {
        do {
            let envelope = try await provider.decide(context: context)
            let rawJSON = try Self.canonicalJSON(envelope)
            let parsedDecision = try parser.parse(rawJSON, expectedAgentId: agent.id, expectedTurn: state.turn)
            var nextState = state
            var commandResults: [CommandResultSummary] = []
            var errors: [String] = parsedDecision.orders.isEmpty ? ["本轮没有生成军令。"] : []

            for (index, order) in parsedDecision.orders.enumerated() {
                do {
                    let issuedCommand = try mapper.map(order, agentId: parsedDecision.agentId, state: nextState)
                    let result = commandHandler.execute(issuedCommand.command, in: nextState)
                    nextState = result.state
                    commandResults.append(
                        .mapped(orderIndex: index, order: order, command: issuedCommand.command, result: result)
                    )

                    if !result.succeeded {
                        errors.append("第 \(index + 1) 条军令被拒绝：\(Self.validationErrorSummary(result.validation.errors))。")
                    }
                } catch {
                    errors.append("第 \(index + 1) 条军令转换失败：\(Self.userFacingError(error))")
                    commandResults.append(.mappingFailed(orderIndex: index, order: order, error: error))
                }
            }

            let endTurnResult = commandHandler.execute(.endTurn, in: nextState)
            nextState = endTurnResult.state
            commandResults.append(.endTurn(result: endTurnResult))
            if !endTurnResult.succeeded {
                errors.append("自动结束回合被拒绝：\(Self.validationErrorSummary(endTurnResult.validation.errors))。")
            }

            let record = AgentDecisionRecord(
                id: "agent_\(agent.id)_turn_\(state.turn)",
                turn: state.turn,
                agentId: agent.id,
                provider: providerName,
                contextSummary: contextSummary,
                rawJSON: rawJSON,
                parsedIntent: parsedDecision.intent,
                commandResults: commandResults,
                errors: errors
            )
            return AgentTurnOutcome(state: nextState, record: record)
        } catch {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: ["朝堂军令执行失败：\(Self.userFacingError(error))"]
                )
            )
        }
    }

    private func runDirectiveTurn(
        state: GameState,
        faction: Faction,
        contextSummary: String
    ) -> AgentTurnOutcome {
        do {
            let diagnostics = directiveDiagnostics(for: faction, state: state)
            let envelope = makeZoneDirectiveEnvelope(state: state, faction: faction, issuerId: agent.id)
            let court = CourtAgent().deliberate(envelope: envelope, theaterEnvelope: nil, in: state)
            let rawJSON = try Self.canonicalCourtDirectiveJSON(
                envelope: court.envelope,
                courtRecord: court.courtRecord,
                prefix: "朝堂调整后的结构化方面军令"
            )
            return executeDirectiveEnvelope(
                court.envelope,
                state: state,
                faction: faction,
                contextSummary: contextSummary,
                rawJSON: rawJSON,
                parsedIntent: "朝堂已调整方面军令",
                providerSuffix: "Directive",
                additionalDiagnostics: diagnostics,
                rulerRecord: court.rulerRecord,
                courtRecord: court.courtRecord
            )
        } catch {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: ["方面军令执行失败：\(Self.userFacingError(error))"]
                )
            )
        }
    }

    private func runMarshalDirectiveTurn(
        state: GameState,
        faction: Faction,
        contextSummary: String
    ) -> AgentTurnOutcome {
        do {
            let diagnostics = directiveDiagnostics(for: faction, state: state)
            let fallbackPool = commanderPool ?? TheaterCommanderPool.automatic(for: state)
            let marshal = marshalAgent ?? MarshalAgent(
                config: MarshalAgentConfig.automatic(for: faction, state: state)
            )
            let resolution = marshal.resolve(
                for: faction,
                in: state,
                fallbackPool: fallbackPool,
                issuerId: agent.id
            )
            let court = CourtAgent().deliberate(
                envelope: resolution.directiveEnvelope,
                theaterEnvelope: resolution.theaterEnvelope,
                in: state
            )
            let compiledJSON = try Self.canonicalCourtDirectiveJSON(
                envelope: court.envelope,
                courtRecord: court.courtRecord,
                prefix: "朝堂调整后的结构化方面军令"
            )
            let rawJSON = resolution.rawTheaterJSON.map {
                "\($0)\n\n\(compiledJSON)"
            } ?? compiledJSON

            return executeDirectiveEnvelope(
                court.envelope,
                state: state,
                faction: faction,
                contextSummary: contextSummary,
                rawJSON: rawJSON,
                parsedIntent: Self.userFacingDiagnostic(court.courtRecord.summary),
                providerSuffix: "MarshalDirective",
                additionalDiagnostics: diagnostics + Self.userFacingDiagnostics(resolution.diagnostics),
                rulerRecord: court.rulerRecord,
                courtRecord: court.courtRecord
            )
        } catch {
            return AgentTurnOutcome(
                state: state,
                record: failureRecord(
                    state: state,
                    contextSummary: contextSummary,
                    rawJSON: nil,
                    parsedIntent: nil,
                    errors: ["军议执行失败：\(Self.userFacingError(error))"]
                )
            )
        }
    }

    private func makeZoneDirectiveEnvelope(
        state: GameState,
        faction: Faction,
        issuerId: String
    ) -> DirectiveEnvelope {
        if state.warDeploymentState.frontZones.isEmpty {
            return DirectiveEnvelope(issuerId: issuerId, turn: state.turn, directives: [])
        }
        if let commanderPool {
            return commanderPool.envelope(for: faction, in: state, issuerId: issuerId)
        }
        return TheaterCommanderPool.automatic(for: state).envelope(for: faction, in: state, issuerId: issuerId)
    }

    private func executeDirectiveEnvelope(
        _ envelope: DirectiveEnvelope,
        state: GameState,
        faction: Faction,
        contextSummary: String,
        rawJSON: String,
        parsedIntent: String,
        providerSuffix: String,
        additionalDiagnostics: [String],
        rulerRecord: RulerDecisionRecord? = nil,
        courtRecord: CourtDecisionRecord? = nil
    ) -> AgentTurnOutcome {
        var nextState = state
        var commandResults: [CommandResultSummary] = []
        var directiveRecords: [WarDirectiveRecord] = []
        var errors = Self.userFacingDiagnostics(additionalDiagnostics)
        if envelope.directives.isEmpty {
            errors.append("本轮未生成方面军令。")
        }

        for (directiveIndex, directive) in envelope.directives.enumerated() {
            let execution = warCommandExecutor.execute(directive, in: nextState)
            nextState = execution.finalState
            var perDirectiveResults: [CommandResultSummary] = []
            var perDirectiveDiagnostics: [String] = []

            if execution.generatedCommands.isEmpty {
                let diagnostic = "第 \(directiveIndex + 1) 条方面军令没有生成可执行命令。"
                errors.append(diagnostic)
                perDirectiveDiagnostics.append(diagnostic)
            }

            for (commandIndex, pair) in zip(execution.generatedCommands, execution.commandResults).enumerated() {
                let summary = CommandResultSummary.directiveCommand(
                    directiveIndex: directiveIndex,
                    commandIndex: commandIndex,
                    directive: directive,
                    command: pair.0,
                    result: pair.1
                )
                commandResults.append(summary)
                perDirectiveResults.append(summary)
                if !pair.1.succeeded {
                    let diagnostic = "第 \(directiveIndex + 1) 条方面军令的第 \(commandIndex + 1) 条命令被拒绝：\(Self.validationErrorSummary(pair.1.validation.errors))。"
                    errors.append(diagnostic)
                    perDirectiveDiagnostics.append(diagnostic)
                }
            }

            let record = WarDirectiveRecord(
                id: "war_directive_\(envelope.issuerId)_turn_\(state.turn)_\(directiveIndex)",
                issuerId: envelope.issuerId,
                turn: state.turn,
                faction: faction,
                zoneId: directive.zoneId,
                directiveType: directive.type,
                targetRegionIds: directive.targetRegionIds,
                commandResults: perDirectiveResults,
                diagnostics: perDirectiveDiagnostics,
                category: directive.category,
                tactic: directive.tactic,
                commanderAgentId: envelope.commanderAgentId,
                commandTarget: directive.commandTarget
            )
            nextState.warDirectiveRecords.append(record)
            directiveRecords.append(record)
        }

        if let rulerRecord {
            nextState.diplomacyState.appendRulerRecord(rulerRecord)
        }
        if let courtRecord {
            nextState.diplomacyState.appendCourtRecord(courtRecord)
            nextState.appendEvent(
                "朝堂决策完成：\(Self.userFacingDiagnostic(courtRecord.summary))",
                category: .event,
                relatedRecordId: courtRecord.id
            )
        }

        let governorExecution = executeGovernorCommands(
            for: faction,
            in: nextState,
            courtRecord: courtRecord
        )
        nextState = governorExecution.state
        commandResults.append(contentsOf: governorExecution.commandResults)
        errors.append(contentsOf: governorExecution.diagnostics)

        let diplomatExecution = executeDiplomatCommands(
            for: faction,
            in: nextState,
            courtRecord: courtRecord
        )
        nextState = diplomatExecution.state
        commandResults.append(contentsOf: diplomatExecution.commandResults)
        errors.append(contentsOf: diplomatExecution.diagnostics)

        let handoffExecution = executeSubmissionHandoffCommands(
            for: faction,
            in: nextState,
            courtRecord: courtRecord
        )
        nextState = handoffExecution.state
        commandResults.append(contentsOf: handoffExecution.commandResults)
        errors.append(contentsOf: handoffExecution.diagnostics)

        let endTurnResult = commandHandler.execute(.endTurn, in: nextState)
        nextState = endTurnResult.state
        commandResults.append(.endTurn(result: endTurnResult))
        if !endTurnResult.succeeded {
            errors.append("自动结束回合被拒绝：\(Self.validationErrorSummary(endTurnResult.validation.errors))。")
        }

        if envelope.directives.isEmpty || !additionalDiagnostics.isEmpty {
            let record = WarDirectiveRecord(
                id: "war_directive_\(envelope.issuerId)_turn_\(state.turn)_diagnostic",
                issuerId: envelope.issuerId,
                turn: state.turn,
                faction: faction,
                zoneId: nil,
                directiveType: nil,
                commandResults: [],
                diagnostics: errors,
                commanderAgentId: envelope.commanderAgentId
            )
            nextState.warDirectiveRecords.append(record)
            directiveRecords.append(record)
        }

        return AgentTurnOutcome(
            state: nextState,
            record: AgentDecisionRecord(
                id: "agent_\(envelope.issuerId)_turn_\(state.turn)_directives",
                turn: state.turn,
                agentId: envelope.issuerId,
                provider: "\(providerName)+\(providerSuffix)",
                contextSummary: contextSummary,
                rawJSON: rawJSON,
                parsedIntent: parsedIntent,
                commandResults: commandResults,
                errors: errors
            ),
            directiveRecords: directiveRecords
        )
    }

    private func executeGovernorCommands(
        for faction: Faction,
        in state: GameState,
        courtRecord: CourtDecisionRecord?
    ) -> GovernorCommandExecution {
        guard let command = governorCommand(for: faction, in: state, courtRecord: courtRecord) else {
            return GovernorCommandExecution(
                state: state,
                commandResults: [],
                diagnostics: governorSkipDiagnostics(for: faction, in: state, courtRecord: courtRecord)
            )
        }

        let result = commandHandler.execute(command, in: state)
        var diagnostics: [String] = []
        if !result.succeeded {
            diagnostics.append("太守经营命令被拒绝：\(Self.validationErrorSummary(result.validation.errors))。")
        }

        return GovernorCommandExecution(
            state: result.state,
            commandResults: [
                .systemCommand(
                    idPrefix: "governor_\(faction.rawValue)",
                    commandIndex: 0,
                    command: command,
                    result: result
                )
            ],
            diagnostics: diagnostics
        )
    }

    private func executeSubmissionHandoffCommands(
        for faction: Faction,
        in state: GameState,
        courtRecord: CourtDecisionRecord?
    ) -> SubmissionHandoffCommandExecution {
        guard hasDiplomatStep(in: courtRecord) else {
            return SubmissionHandoffCommandExecution(state: state, commandResults: [], diagnostics: [])
        }
        guard let command = submissionHandoffCommand(for: faction, in: state) else {
            return SubmissionHandoffCommandExecution(
                state: state,
                commandResults: [],
                diagnostics: submissionHandoffSkipDiagnostics(for: faction, in: state, courtRecord: courtRecord)
            )
        }

        let result = commandHandler.execute(command, in: state)
        var diagnostics: [String] = []
        if !result.succeeded {
            diagnostics.append("归附交接命令被拒绝：\(Self.validationErrorSummary(result.validation.errors))。")
        }

        return SubmissionHandoffCommandExecution(
            state: result.state,
            commandResults: [
                .systemCommand(
                    idPrefix: "submission_handoff_\(faction.rawValue)",
                    commandIndex: 0,
                    command: command,
                    result: result
                )
            ],
            diagnostics: diagnostics
        )
    }

    private func executeDiplomatCommands(
        for faction: Faction,
        in state: GameState,
        courtRecord: CourtDecisionRecord?
    ) -> DiplomatCommandExecution {
        guard let command = diplomatCommand(for: faction, in: state, courtRecord: courtRecord) else {
            return DiplomatCommandExecution(
                state: state,
                commandResults: [],
                diagnostics: diplomatSkipDiagnostics(for: faction, in: state, courtRecord: courtRecord)
            )
        }

        let result = commandHandler.execute(command, in: state)
        var diagnostics: [String] = []
        if !result.succeeded {
            diagnostics.append("使者外交命令被拒绝：\(Self.validationErrorSummary(result.validation.errors))。")
        }

        return DiplomatCommandExecution(
            state: result.state,
            commandResults: [
                .systemCommand(
                    idPrefix: "diplomat_\(faction.rawValue)",
                    commandIndex: 0,
                    command: command,
                    result: result
                )
            ],
            diagnostics: diagnostics
        )
    }

    private func hasDiplomatStep(in courtRecord: CourtDecisionRecord?) -> Bool {
        courtRecord?.steps.contains(where: { $0.role == .diplomat }) == true
    }

    private func diplomatCommand(
        for faction: Faction,
        in state: GameState,
        courtRecord: CourtDecisionRecord?
    ) -> Command? {
        guard hasDiplomatStep(in: courtRecord) else {
            return nil
        }
        guard !state.diplomacyState.countries(for: faction).isEmpty else {
            return nil
        }

        let hostiles = hostileFactions(to: faction, in: state)
        guard !hostiles.isEmpty else {
            return nil
        }

        if let submittedTarget = hostiles.first(where: { shouldSeekSubmission(of: $0, in: state) }) {
            return Command.updateDiplomacy(issuer: faction, target: submittedTarget, status: DiplomaticStatus.submitted)
        }

        guard shouldSeekTruce(for: faction, hostileCount: hostiles.count, in: state) else {
            return nil
        }

        var truceCandidates: [(faction: Faction, score: Int)] = []
        for target in hostiles {
            truceCandidates.append((
                faction: target,
                score: diplomaticPressureScore(for: target, in: state)
            ))
        }
        let truceTarget = truceCandidates.sorted {
            $0.score == $1.score
                ? $0.faction.rawValue < $1.faction.rawValue
                : $0.score > $1.score
        }.first?.faction

        return truceTarget.map { target in
            Command.updateDiplomacy(issuer: faction, target: target, status: DiplomaticStatus.truce)
        }
    }

    private func submissionHandoffCommand(for faction: Faction, in state: GameState) -> Command? {
        guard !state.diplomacyState.countries(for: faction).isEmpty else {
            return nil
        }

        var candidates: [(faction: Faction, score: Int)] = []
        for submitted in state.diplomacyState.submittedTargetFactions() {
            guard submitted != faction,
                  state.diplomacyState.canResolveSubmissionHandoff(
                    submitted: submitted,
                    recipient: faction
                  ),
                  hasSubmissionRuntimePresence(submitted, in: state) else {
                continue
            }
            candidates.append((
                faction: submitted,
                score: submissionPresenceScore(for: submitted, in: state)
            ))
        }
        let sortedCandidates = candidates.sorted {
            $0.score == $1.score
                ? $0.faction.rawValue < $1.faction.rawValue
                : $0.score > $1.score
        }

        return sortedCandidates.first.map {
            Command.resolveSubmissionHandoff(submitted: $0.faction, recipient: faction)
        }
    }

    private func diplomatSkipDiagnostics(
        for faction: Faction,
        in state: GameState,
        courtRecord: CourtDecisionRecord?
    ) -> [String] {
        guard hasDiplomatStep(in: courtRecord) else {
            return []
        }

        var reasons: [String] = []
        if state.diplomacyState.countries(for: faction).isEmpty {
            reasons.append("当前势力缺少国家档案")
        }

        let hostiles = hostileFactions(to: faction, in: state)
        if hostiles.isEmpty {
            reasons.append("没有带国家档案的敌对势力")
        } else {
            let submissionTargets = hostiles.filter { shouldSeekSubmission(of: $0, in: state) }
            if submissionTargets.isEmpty {
                reasons.append("没有敌对势力达到可归附条件")
            }

            if !shouldSeekTruce(for: faction, hostileCount: hostiles.count, in: state) {
                reasons.append(
                    "停战阈值未触发：战意 \(primaryWarSupport(for: faction, in: state))，可行动军队 \(activeDivisionCount(for: faction, in: state))，可通行受控州郡 \(controlledPassableRegionCount(for: faction, in: state))，敌对势力 \(hostiles.count)"
                )
            }
        }

        if reasons.isEmpty {
            reasons.append("没有外交目标通过归附或停战检查")
        }

        return ["使者未生成外交命令：\(reasons.joined(separator: "；"))。"]
    }

    private func submissionHandoffSkipDiagnostics(
        for faction: Faction,
        in state: GameState,
        courtRecord: CourtDecisionRecord?
    ) -> [String] {
        let submittedTargets = state.diplomacyState.submittedTargetFactions()
            .filter { $0 != faction }
        guard hasDiplomatStep(in: courtRecord), !submittedTargets.isEmpty else {
            return []
        }

        var reasons: [String] = []
        if state.diplomacyState.countries(for: faction).isEmpty {
            reasons.append("当前接收方缺少国家档案")
        }

        let receivableTargets = submittedTargets.filter {
            state.diplomacyState.canResolveSubmissionHandoff(
                submitted: $0,
                recipient: faction
            )
        }
        if receivableTargets.isEmpty {
            let targetList = submittedTargets
                .map { Self.userFacingDiagnostic($0.displayName) }
                .joined(separator: "、")
            reasons.append("归附目标不属于当前接收方：\(targetList)")
        } else {
            let presentTargets = receivableTargets.filter { hasSubmissionRuntimePresence($0, in: state) }
            if presentTargets.isEmpty {
                let targetList = receivableTargets
                    .map { Self.userFacingDiagnostic($0.displayName) }
                    .joined(separator: "、")
                reasons.append("归附目标已无残余军队或可通行受控地块：\(targetList)")
            }
        }

        if reasons.isEmpty {
            reasons.append("没有归附目标通过接收方和实体存在检查")
        }

        return ["未生成归附交接命令：\(reasons.joined(separator: "；"))。"]
    }

    private func hostileFactions(to faction: Faction, in state: GameState) -> [Faction] {
        let candidates = Set(state.map.regions.values.compactMap(\.controller))
            .union(state.divisions.map(\.faction))
            .union(state.diplomacyState.countries.map(\.faction))
            .subtracting([faction])
        return candidates
            .filter {
                !state.diplomacyState.countries(for: $0).isEmpty &&
                    state.diplomacyState.isHostile(faction, $0)
            }
            .sorted { $0.rawValue < $1.rawValue }
    }

    private func shouldSeekSubmission(of target: Faction, in state: GameState) -> Bool {
        activeDivisionCount(for: target, in: state) == 0 &&
            controlledPassableRegionCount(for: target, in: state) == 0
    }

    private func shouldSeekTruce(
        for faction: Faction,
        hostileCount: Int,
        in state: GameState
    ) -> Bool {
        primaryWarSupport(for: faction, in: state) <= 45 ||
            activeDivisionCount(for: faction, in: state) <= 1 ||
            (controlledPassableRegionCount(for: faction, in: state) <= 1 && hostileCount > 1)
    }

    private func diplomaticPressureScore(for faction: Faction, in state: GameState) -> Int {
        controlledPassableRegionCount(for: faction, in: state) * 3 +
            activeDivisionCount(for: faction, in: state) * 2 +
            primaryWarSupport(for: faction, in: state) / 10
    }

    private func activeDivisionCount(for faction: Faction, in state: GameState) -> Int {
        state.divisions.count { $0.faction == faction && !$0.isDestroyed }
    }

    private func hasSubmissionRuntimePresence(_ faction: Faction, in state: GameState) -> Bool {
        activeDivisionCount(for: faction, in: state) > 0 ||
            controlledPassableHexCount(for: faction, in: state) > 0
    }

    private func submissionPresenceScore(for faction: Faction, in state: GameState) -> Int {
        activeDivisionCount(for: faction, in: state) * 10 +
            controlledPassableHexCount(for: faction, in: state)
    }

    private func controlledPassableHexCount(for faction: Faction, in state: GameState) -> Int {
        state.map.tiles.values.count { $0.controller == faction && $0.isPassable }
    }

    private func controlledPassableRegionCount(for faction: Faction, in state: GameState) -> Int {
        state.map.regions.values.count { $0.controller == faction && $0.isPassable }
    }

    private func primaryWarSupport(for faction: Faction, in state: GameState) -> Int {
        state.diplomacyState.primaryCountry(for: faction)?.warSupport ?? 70
    }

    private func governorCommand(
        for faction: Faction,
        in state: GameState,
        courtRecord: CourtDecisionRecord?
    ) -> Command? {
        let aftermathFocusedRegionIds = aftermathGovernorRegionIds(for: faction, in: state)
        let aftermathFocusedRegionIdSet = Set(aftermathFocusedRegionIds)
        let courtFocusedRegionIds = courtRecord?.steps
            .first(where: { $0.role == .governor })?
            .targetRegionIds ?? []
        let focusedRegionIds = orderedUniqueRegionIds(aftermathFocusedRegionIds + courtFocusedRegionIds)
        let focused = focusedRegionIds.compactMap { state.map.region(id: $0) }
        let focusedIds = Set(focused.map(\.id))
        let remaining = state.map.regions.values
            .filter { !focusedIds.contains($0.id) }
            .map { region in
                (
                    region: region,
                    score: governorRegionScore(region, faction: faction, state: state)
                )
            }
            .sorted {
                $0.score == $1.score
                    ? $0.region.id.rawValue < $1.region.id.rawValue
                    : $0.score > $1.score
            }
            .map { $0.region }
        let candidates = focused + remaining

        for region in candidates where canGovernorConsider(region, faction: faction, state: state) {
            let prefersPacification = aftermathFocusedRegionIdSet.contains(region.id)
            guard let policy = governorPolicy(
                for: region,
                faction: faction,
                state: state,
                prefersPacification: prefersPacification
            ) else {
                continue
            }
            return .governRegion(regionId: region.id, policy: policy)
        }
        return nil
    }

    private func aftermathGovernorRegionIds(for faction: Faction, in state: GameState) -> [RegionId] {
        guard let record = actionableAftermathRecord(for: faction, in: state) else {
            return []
        }
        let affectedRegionIds = orderedUniqueRegionIds(record.affectedRegionIds)
        let ungovernedRegionIds = state.diplomacyState.ungovernedAftermathRegionIds(
            linkedTo: record.id,
            affectedRegionIds: affectedRegionIds
        )
        let governedRegionIds = state.diplomacyState.governedAftermathRegionIds(
            linkedTo: record.id,
            affectedRegionIds: affectedRegionIds
        )
        let prioritizedRegionIds = ungovernedRegionIds + governedRegionIds

        return prioritizedRegionIds.filter { regionId in
            guard let region = state.map.region(id: regionId) else {
                return false
            }
            return canGovernorConsider(region, faction: faction, state: state)
        }
    }

    private func actionableAftermathRecord(for faction: Faction, in state: GameState) -> SubmissionAftermathRecord? {
        guard let record = state.diplomacyState.latestSubmissionAftermathRecord,
              record.recipient == faction,
              record.riskLevel != .low else {
            return nil
        }

        let affectedRegionIds = orderedUniqueRegionIds(record.affectedRegionIds)
        guard !state.diplomacyState.isAftermathGovernanceComplete(
            linkedTo: record.id,
            affectedRegionIds: affectedRegionIds
        ) else {
            return nil
        }

        return record
    }

    private func governorSkipDiagnostics(
        for faction: Faction,
        in state: GameState,
        courtRecord: CourtDecisionRecord?
    ) -> [String] {
        let hasGovernorStep = courtRecord?.steps.contains(where: { $0.role == .governor }) == true
        let aftermathRecord = actionableAftermathRecord(for: faction, in: state)
        guard hasGovernorStep || aftermathRecord != nil else {
            return []
        }

        let candidateRegions = state.map.regions.values.filter {
            canGovernorConsider($0, faction: faction, state: state)
        }
        var reasons: [String] = []

        if candidateRegions.isEmpty {
            reasons.append("没有同时满足己方控制、可通行且含己方受控地块的州郡")
        } else {
            let aftermathFocusedRegionIds = Set(aftermathGovernorRegionIds(for: faction, in: state))
            let hasApplicablePolicy = candidateRegions.contains { region in
                governorPolicy(
                    for: region,
                    faction: faction,
                    state: state,
                    prefersPacification: aftermathFocusedRegionIds.contains(region.id)
                ) != nil
            }

            if !hasApplicablePolicy {
                reasons.append("没有可用或府库可负担的治理政策")
            }
        }

        if let aftermathRecord {
            let affectedRegionIds = orderedUniqueRegionIds(aftermathRecord.affectedRegionIds)
            let ungovernedCount = state.diplomacyState.ungovernedAftermathRegionCount(
                linkedTo: aftermathRecord.id,
                affectedRegionIds: affectedRegionIds
            )
            reasons.append("最新善后仍有 \(ungovernedCount) 个州郡待处置")
        }

        if reasons.isEmpty {
            reasons.append("没有州郡通过太守候选评分和政策检查")
        }

        return ["太守未生成经营命令：\(reasons.joined(separator: "；"))。"]
    }

    private func orderedUniqueRegionIds(_ regionIds: [RegionId]) -> [RegionId] {
        var seen: Set<RegionId> = []
        var ordered: [RegionId] = []
        for regionId in regionIds where !seen.contains(regionId) {
            seen.insert(regionId)
            ordered.append(regionId)
        }
        return ordered
    }

    private func canGovernorConsider(_ region: RegionNode, faction: Faction, state: GameState) -> Bool {
        region.controller == faction &&
            region.isPassable &&
            region.displayHexes.contains { state.map.tile(at: $0)?.controller == faction }
    }

    private func governorPolicy(
        for region: RegionNode,
        faction: Faction,
        state: GameState,
        prefersPacification: Bool = false
    ) -> RegionGovernancePolicy? {
        let ledger = state.economyState.ledger(for: faction)
        let basePreferredPolicies: [RegionGovernancePolicy]
        if region.supplyValue <= 2 {
            basePreferredPolicies = [.organizeTuntian, .repairRoads, .pacifyPopulation]
        } else if region.infrastructure <= 2 {
            basePreferredPolicies = [.repairRoads, .organizeTuntian, .pacifyPopulation]
        } else {
            basePreferredPolicies = [.pacifyPopulation, .organizeTuntian, .repairRoads]
        }
        let preferredPolicies = prefersPacification
            ? [.pacifyPopulation] + basePreferredPolicies.filter { $0 != .pacifyPopulation }
            : basePreferredPolicies

        return preferredPolicies.first { policy in
            policy.canApply(to: region) && ledger.stockpile.canAfford(policy.cost)
        }
    }

    private func governorRegionScore(_ region: RegionNode, faction: Faction, state: GameState) -> Int {
        var score = 0
        if region.supplyValue <= 2 {
            score += 8
        }
        if region.infrastructure <= 2 {
            score += 6
        }
        if let occupation = region.occupationState {
            score += max(0, occupation.resistance / 5)
            score += max(0, (70 - occupation.compliance) / 10)
        } else if !region.coreOf.isEmpty && !region.coreOf.contains(faction) {
            score += 2
        }
        score += state.divisions
            .filter { $0.faction == faction && $0.location(in: state.map) == region.id }
            .count
        return score
    }

    private func isAITurn(faction: Faction, state: GameState) -> Bool {
        let normalizedPhase = state.phase.normalized(
            forActiveFaction: state.activeFaction,
            playerFaction: state.playerFaction
        )
        return state.activeFaction == faction && normalizedPhase.allowsCommandExecution(
            forActiveFaction: state.activeFaction,
            playerFaction: state.playerFaction
        )
    }

    private func directiveDiagnostics(for faction: Faction, state: GameState) -> [String] {
        var diagnostics: [String] = []
        if state.warDeploymentState.frontZones.isEmpty {
            diagnostics.append("已进入方面军令流程，但当前没有行军防区数据；未回退备用军议路径。")
        }

        for division in state.divisions where division.faction == faction && !division.isDestroyed {
            guard let regionId = division.location(in: state.map),
                  state.warDeploymentState.regionToFrontZone[regionId] != nil else {
                diagnostics.append("军队 \(division.name) 尚未分配到行军防区，未生成对应方面军令。")
                continue
            }
        }

        return diagnostics
    }

    private func failureRecord(
        state: GameState,
        contextSummary: String,
        rawJSON: String?,
        parsedIntent: String?,
        errors: [String]
    ) -> AgentDecisionRecord {
        AgentDecisionRecord(
            id: "agent_\(agent.id)_turn_\(state.turn)_failed",
            turn: state.turn,
            agentId: agent.id,
            provider: providerName,
            contextSummary: contextSummary,
            rawJSON: rawJSON,
            parsedIntent: parsedIntent,
            commandResults: [],
            errors: Self.userFacingDiagnostics(errors)
        )
    }

    static func contextSummary(_ context: AgentContext) -> String {
        "第 \(context.turn) 回合：己方军队 \(context.friendlyDivisions.count) 支，已知敌军 \(context.enemyDivisions.count) 支，可见目标 \(context.objectives.count) 处。"
    }

    static func canonicalJSON(_ envelope: AgentDecisionEnvelope) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)
        return String(decoding: data, as: UTF8.self)
    }

    static func canonicalDirectiveJSON(_ envelope: DirectiveEnvelope) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)
        return String(decoding: data, as: UTF8.self)
    }

    static func canonicalCourtDirectiveJSON(
        envelope: DirectiveEnvelope,
        courtRecord: CourtDecisionRecord,
        prefix: String
    ) throws -> String {
        let directiveJSON = try canonicalDirectiveJSON(envelope)
        let steps = courtRecord.steps
            .map { "- \($0.role.displayName)：\(userFacingDiagnostic($0.summary))" }
            .joined(separator: "\n")
        return "\(prefix):\n\(directiveJSON)\n\n朝堂步骤：\n\(steps)"
    }

    private static func validationErrorSummary(_ errors: [CommandValidationError]) -> String {
        if errors.isEmpty {
            return "无错误"
        }
        return errors.map(\.displayName).joined(separator: "、")
    }

    private static func userFacingDiagnostics(_ diagnostics: [String]) -> [String] {
        diagnostics.map(userFacingDiagnostic)
    }

    private static func userFacingDiagnostic(_ diagnostic: String) -> String {
        sanitizeRawIdentifiers(in: diagnostic)
            .replacingOccurrences(of: "德军（旧）", with: "旧剧本势力")
            .replacingOccurrences(of: "盟军（旧）", with: "旧剧本势力")
            .replacingOccurrences(of: "德军", with: "旧剧本势力")
            .replacingOccurrences(of: "盟军", with: "旧剧本势力")
            .replacingOccurrences(of: "旧剧本德方", with: "旧剧本国家")
            .replacingOccurrences(of: "旧剧本美方", with: "旧剧本国家")
            .replacingOccurrences(of: "旧剧本英方", with: "旧剧本国家")
            .replacingOccurrences(of: "Heinz Guderian", with: "历史总管")
            .replacingOccurrences(of: "Guderian", with: "历史总管")
            .replacingOccurrences(of: "Field Marshal", with: "行军总管")
            .replacingOccurrences(of: "Army Commander", with: "行军总管")
            .replacingOccurrences(of: "Germany", with: "旧剧本势力")
            .replacingOccurrences(of: "Allies", with: "旧剧本势力")
            .replacingOccurrences(of: "German", with: "旧剧本势力")
            .replacingOccurrences(of: "Ruler", with: "君主")
            .replacingOccurrences(of: "rawJSON", with: "军情记录")
            .replacingOccurrences(of: "JSON", with: "军情记录")
            .replacingOccurrences(of: "json", with: "军情记录")
            .replacingOccurrences(of: "schema", with: "格式")
            .replacingOccurrences(of: "provider", with: "来源")
            .replacingOccurrences(of: "local-model", with: "本地军议来源")
            .replacingOccurrences(of: "Model", with: "军议来源")
            .replacingOccurrences(of: "model", with: "军议来源")
            .replacingOccurrences(of: "ZoneDirective", with: "方面军令")
            .replacingOccurrences(of: "WarDeploymentState", with: "行军部署")
            .replacingOccurrences(of: "FrontZone", with: "行军防区")
            .replacingOccurrences(of: "Division", with: "军队")
            .replacingOccurrences(of: "Legacy pipeline", with: "备用军议路径")
            .replacingOccurrences(of: "legacy pipeline", with: "备用军议路径")
            .replacingOccurrences(of: "Fallback", with: "备用处置")
            .replacingOccurrences(of: "fallback", with: "备用处置")
            .replacingOccurrences(of: "Command", with: "命令")
            .replacingOccurrences(of: "RuleEngine", with: "军令校验")
            .replacingOccurrences(of: "反装甲", with: "拒马弩")
            .replacingOccurrences(of: "反甲骑", with: "拒马弩")
            .replacingOccurrences(of: "装甲", with: "甲骑")
            .replacingOccurrences(of: "摩托化", with: "骑军")
            .replacingOccurrences(of: "炮兵", with: "弓弩")
            .replacingOccurrences(of: "步兵", with: "步卒")
            .replacingOccurrences(of: "阿登", with: "旧战局")
            .replacingOccurrences(of: "巴斯托涅", with: "旧战局要地")
            .replacingOccurrences(of: "圣维特", with: "旧战局要地")
            .replacingOccurrences(of: "Ardennes", with: "旧战局")
            .replacingOccurrences(of: "Bastogne", with: "旧战局要地")
            .replacingOccurrences(of: "St. Vith", with: "旧战局要地")
            .replacingOccurrences(of: "St Vith", with: "旧战局要地")
            .replacingOccurrences(of: "Agent", with: "朝堂成员")
            .replacingOccurrences(of: "agent", with: "朝堂成员")
            .replacingOccurrences(of: "MockAI", with: "本地模拟朝堂")
            .replacingOccurrences(of: "directive", with: "军令")
            .replacingOccurrences(of: "Diagnostic", with: "军情说明")
            .replacingOccurrences(of: "diagnostic", with: "军情说明")
            .replacingOccurrences(of: "breakthrough", with: "突破")
            .replacingOccurrences(of: "hexToTheater", with: "方面归属")
            .replacingOccurrences(of: "HexTile", with: "地块")
            .replacingOccurrences(of: "Hexes", with: "地块")
            .replacingOccurrences(of: "Hex", with: "地块")
            .replacingOccurrences(of: "hexes", with: "地块")
            .replacingOccurrences(of: "hex", with: "地块")
    }

    private static func sanitizeRawIdentifiers(in text: String) -> String {
        text
            .replacingOccurrences(
                of: #"\bwar_directive_[A-Za-z0-9_\-]+\b"#,
                with: "方面军令审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bplayer_directive_[A-Za-z0-9_\-]+\b"#,
                with: "玩家军令审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bplayer_operation_[A-Za-z0-9_\-]+\b"#,
                with: "预备军令审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bsubmission_handoff_[A-Za-z0-9_\-]+\b"#,
                with: "归附交接审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bsubmission_aftermath_[A-Za-z0-9_\-]+\b"#,
                with: "归附善后审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bdiplomacy_event_[A-Za-z0-9_\-]+\b"#,
                with: "外交记录",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bdiplomacy_[0-9]+_[A-Za-z0-9_\-]+\b"#,
                with: "外交记录",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bcourt_decision_[A-Za-z0-9_\-]+\b"#,
                with: "朝堂审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bcourt_[A-Za-z0-9_\-]+_turn_[0-9]+\b"#,
                with: "朝堂审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bcourt_[0-9]+_[A-Za-z0-9_\-]+\b"#,
                with: "朝堂审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bruler_decision_[A-Za-z0-9_\-]+\b"#,
                with: "君主审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bruler_[A-Za-z0-9_\-]+_turn_[A-Za-z0-9_\-]+\b"#,
                with: "君主审计",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bdirective_[A-Za-z0-9_\-]*command_[A-Za-z0-9_\-]+\b"#,
                with: "相关军令",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\border_[A-Za-z0-9_\-]+\b"#,
                with: "相关指令",
                options: .regularExpression
            )
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
                of: #"\bfront_zone_[A-Za-z0-9_\-]+\b"#,
                with: "相关防区",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bobj_[A-Za-z0-9_\-]+\b"#,
                with: "相关要地",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bhex_[A-Za-z0-9_\-]+\b"#,
                with: "相关地块",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(division|unit)_[A-Za-z0-9_\-]+\b"#,
                with: "相关军队",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bcommand_[A-Za-z0-9_\-]+\b"#,
                with: "相关军令",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(agent|marshal|mock|sovereign|strategist|diplomat|governor_staff|march_commander|general_staff)_[A-Za-z0-9_\-]+\b"#,
                with: "朝堂记录",
                options: .regularExpression
            )
    }

    private static func userFacingError(_ error: Error) -> String {
        if error is DecodingError {
            return "结构化原文无法解析。"
        }
        if error is EncodingError {
            return "结构化原文无法生成。"
        }
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            let userFacingDescription = userFacingDiagnostic(description)
            if !containsLikelyEnglish(userFacingDescription) {
                return userFacingDescription
            }
        }
        return "原因未明。"
    }

    private static func containsLikelyEnglish(_ text: String) -> Bool {
        text.range(of: #"[A-Za-z]{2,}"#, options: .regularExpression) != nil
    }
}
