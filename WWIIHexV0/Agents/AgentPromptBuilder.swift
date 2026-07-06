import Foundation

// DEPRECATED as of v0.352 - kept for regression reference, not invoked by default. See WarPipelineMode.
// Builds LLM prompt from AgentContext. v0 keeps it simple; mostly for LocalLLMDecisionProvider.

struct AgentPromptBuilder {
    func makeRequest(
        context: AgentContext,
        model: String,
        temperature: Double = 0.2,
        maxTokens: Int = 1200
    ) -> LLMRequest {
        LLMRequest(
            model: model,
            systemPrompt: systemPrompt(context: context),
            userPrompt: userPrompt(context: context),
            temperature: temperature,
            maxTokens: maxTokens,
            responseFormat: "json_object"
        )
    }

    private func systemPrompt(context: AgentContext) -> String {
        let agentName = displayAgentName(context.agentId)
        let factionName = displayFactionName(context.faction)
        let personality = sanitizePromptText(context.personality)
        return """
        你是本地军议决策层，负责为回合制六角格策略战局生成结构化军令。
        决策者：\(agentName)
        势力：\(factionName)
        性格：\(personality)

        只返回符合下方结构化格式的 JSON 内容，不要输出说明、排版标记、注释或额外字段。
        intent、reason、stance 摘要必须使用中文。
        intent、reason、stance 不得复述内部编号、字段名或命令类型原值，除非字段本身要求填写编号。
        不得假设不可见情报，不得修改规则，不得虚构军队，不得绕过命令校验。
        """
    }

    private func userPrompt(context: AgentContext) -> String {
        let regionNames = Dictionary(uniqueKeysWithValues: context.visibleRegions.map { ($0.id, $0.name) })
        let aliases = AgentPromptAliasBook(context: context)
        let objectives = context.objectives
            .map { "\(displayMapName($0.name, fallback: "要地"))；州郡：\(displayRegionName($0.regionId, regionNames: regionNames))；控制：\(displayFactionName($0.controller))" }
            .joined(separator: "\n")
        let friendly = context.friendlyDivisions
            .map { "\(displayDivisionName($0.name, faction: $0.faction))；兵力：\($0.strength)/\($0.maxStrength)；位置：\(displayRegionName($0.regionId, regionNames: regionNames))；补给：\($0.supplyState.displayName)；已行动：\($0.hasActed ? "是" : "否")" }
            .joined(separator: "\n")
        let enemies = context.enemyDivisions
            .map { "\(displayDivisionName($0.name, faction: $0.faction))；兵力：\($0.strength)/\($0.maxStrength)；位置：\(displayRegionName($0.regionId, regionNames: regionNames))" }
            .joined(separator: "\n")
        let regions = context.visibleRegions
            .filter(\.visible)
            .map { "\(displayMapName($0.name, fallback: "州郡"))；地形：\($0.terrain.displayName)；控制：\(displayFactionName($0.controller))；相邻：\(neighborNames(for: $0, regionNames: regionNames))" }
            .joined(separator: "\n")
        let recentEvents = context.recentEvents
            .map { sanitizePromptText($0.message) }
            .joined(separator: "\n")
        let playerDirective = context.playerDirective.map(sanitizePromptText) ?? "无"
        let friendlyIds = context.friendlyDivisions
            .map { "divisionId=\(aliases.alias(forFriendlyDivisionId: $0.id))（\(displayDivisionName($0.name, faction: $0.faction))，位置：\(displayRegionName($0.regionId, regionNames: regionNames))）" }
            .joined(separator: "\n")
        let enemyIds = context.enemyDivisions
            .map { "targetDivisionId=\(aliases.alias(forEnemyDivisionId: $0.id))（\(displayDivisionName($0.name, faction: $0.faction))，位置：\(displayRegionName($0.regionId, regionNames: regionNames))）" }
            .joined(separator: "\n")
        let regionIds = context.visibleRegions
            .filter(\.visible)
            .map { "toRegionId=\(aliases.alias(forRegionId: $0.id))（\(displayMapName($0.name, fallback: "州郡"))）" }
            .joined(separator: "\n")

        return """
        当前任务：
        为本决策者所属军队生成第 \(context.turn) 回合、\(context.phase.displayName) 阶段的作战军令。

        可用命令：
        - 行军：type 字段必须填 "move"，并提供 divisionId 和 toRegionId。
        - 攻击：type 字段必须填 "attack"，并提供 divisionId 和 targetDivisionId。
        - 固守：type 字段必须填 "hold"，并提供 divisionId。
        - 整补：type 字段必须填 "resupply"，并提供 divisionId。

        战场摘要：
        己方军队：
        \(friendly)

        已知敌军：
        \(enemies)

        目标：
        \(objectives)

        可见州郡：
        \(regions)

        补给：
        己方补给正常 \(context.supplySummary.friendlySupplied)，补给不足 \(context.supplySummary.friendlyLowSupply)，被围 \(context.supplySummary.friendlyEncircled)

        近期战报：
        \(recentEvents)

        玩家意图：
        \(playerDirective)

        提交军令时必须使用的临时编号：
        己方军队编号：
        \(friendlyIds)

        敌军目标编号：
        \(enemyIds)

        可行军州郡编号：
        \(regionIds)

        临时编号只用于结构化军令字段取值，不要写进 intent、reason 或 stance。

        结构化输出格式：
        {
          "schemaVersion": 2,
          "agentId": "\(aliases.agentIdAlias)",
          "turn": \(context.turn),
          "intent": "一句中文作战意图",
          "orders": [
            {
              "type": "必须填 move、attack、hold 或 resupply 之一",
              "divisionId": "从己方军队编号中选择",
              "toRegionId": "行军时从可行军州郡编号中选择，否则为 null",
              "targetDivisionId": null,
              "stance": "中文态势短语或 null",
              "reason": "一句中文理由"
            }
          ]
        }
        """
    }

    private func displayRegionName(_ regionId: RegionId?, regionNames: [RegionId: String]) -> String {
        guard let regionId else {
            return "未知州郡"
        }
        guard let name = regionNames[regionId] else {
            return "未知州郡"
        }
        return displayMapName(name, fallback: "州郡")
    }

    private func neighborNames(for region: RegionSnapshot, regionNames: [RegionId: String]) -> String {
        let names = region.neighbors.map { regionNames[$0] ?? "相邻州郡" }
        return names.isEmpty ? "无" : names.joined(separator: "、")
    }

    private func displayAgentName(_ agentId: String) -> String {
        switch agentId {
        case "guderian":
            return "本地军议决策者"
        default:
            return agentId.range(of: #"^[A-Za-z0-9_\-]+$"#, options: .regularExpression) == nil
                ? agentId
                : "本地军议决策者"
        }
    }

    private func displayFactionName(_ faction: Faction?) -> String {
        guard let faction else {
            return "中立"
        }
        switch faction {
        case .germany, .allies:
            return "旧剧本势力"
        default:
            return sanitizePromptText(faction.displayName)
        }
    }

    private func displayDivisionName(_ name: String, faction: Faction) -> String {
        let sanitized = sanitizePromptText(name)
        return sanitized.isEmpty ? "\(displayFactionName(faction))军队" : sanitized
    }

    private func displayMapName(_ name: String, fallback: String) -> String {
        let sanitized = sanitizePromptText(name)
        return sanitized.isEmpty ? fallback : sanitized
    }

    private func sanitizePromptText(_ text: String) -> String {
        sanitizeRawIdentifiers(in: text)
            .replacingOccurrences(of: "Heinz Guderian", with: "历史总管")
            .replacingOccurrences(of: "Guderian", with: "历史总管")
            .replacingOccurrences(of: "德军（旧）", with: "旧剧本势力")
            .replacingOccurrences(of: "盟军（旧）", with: "旧剧本势力")
            .replacingOccurrences(of: "德军", with: "旧剧本势力")
            .replacingOccurrences(of: "盟军", with: "旧剧本势力")
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
            .replacingOccurrences(of: "Sedan", with: "旧战局要地")
            .replacingOccurrences(of: "rawJSON", with: "军情记录")
            .replacingOccurrences(of: "raw JSON", with: "军情记录")
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
            .replacingOccurrences(of: "MockAI", with: "本地模拟朝堂")
            .replacingOccurrences(of: "OpenAI", with: "军议来源")
            .replacingOccurrences(of: "GPT", with: "军议来源")
            .replacingOccurrences(of: "Claude", with: "军议来源")
            .replacingOccurrences(of: "Gemini", with: "军议来源")
            .replacingOccurrences(of: "AI", with: "军议")
            .replacingOccurrences(of: "LLM", with: "军议")
            .replacingOccurrences(of: "diagnostic", with: "军情说明")
            .replacingOccurrences(of: "breakthrough", with: "突破")
            .replacingOccurrences(of: "hexToTheater", with: "方面归属")
            .replacingOccurrences(of: "HexTile", with: "地块")
            .replacingOccurrences(of: "Hexes", with: "地块")
            .replacingOccurrences(of: "Hex", with: "地块")
            .replacingOccurrences(of: "hexes", with: "地块")
            .replacingOccurrences(of: "hex", with: "地块")
    }

    private func sanitizeRawIdentifiers(in text: String) -> String {
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
                of: #"\b(obj|objective)_[A-Za-z0-9_\-]+\b"#,
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
                of: #"\bagent_[A-Za-z0-9_\-]+\b"#,
                with: "朝堂记录",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(marshal|mock|sovereign|strategist|diplomat|governor_staff|march_commander|general_staff)_[A-Za-z0-9_\-]+\b"#,
                with: "朝堂记录",
                options: .regularExpression
            )
    }
}

struct AgentPromptAliasBook {
    let agentIdAlias = "本地决策者"

    private let friendlyDivisionAliasesById: [String: String]
    private let enemyDivisionAliasesById: [String: String]
    private let regionAliasesById: [RegionId: String]
    private let friendlyDivisionIdsByAlias: [String: String]
    private let enemyDivisionIdsByAlias: [String: String]
    private let regionIdsByAlias: [String: RegionId]

    init(context: AgentContext) {
        let friendlyPairs = context.friendlyDivisions.enumerated().map { index, division in
            (division.id, "军队\(Self.chineseOrdinal(index + 1))")
        }
        let enemyPairs = context.enemyDivisions.enumerated().map { index, division in
            (division.id, "敌军\(Self.chineseOrdinal(index + 1))")
        }
        let regionPairs = context.visibleRegions
            .filter(\.visible)
            .enumerated()
            .map { index, region in
                (region.id, "州郡\(Self.chineseOrdinal(index + 1))")
            }

        self.friendlyDivisionAliasesById = Dictionary(uniqueKeysWithValues: friendlyPairs)
        self.enemyDivisionAliasesById = Dictionary(uniqueKeysWithValues: enemyPairs)
        self.regionAliasesById = Dictionary(uniqueKeysWithValues: regionPairs)
        self.friendlyDivisionIdsByAlias = Dictionary(uniqueKeysWithValues: friendlyPairs.map { ($0.1, $0.0) })
        self.enemyDivisionIdsByAlias = Dictionary(uniqueKeysWithValues: enemyPairs.map { ($0.1, $0.0) })
        self.regionIdsByAlias = Dictionary(uniqueKeysWithValues: regionPairs.map { ($0.1, $0.0) })
    }

    func alias(forFriendlyDivisionId id: String) -> String {
        friendlyDivisionAliasesById[id] ?? "军队"
    }

    func alias(forEnemyDivisionId id: String) -> String {
        enemyDivisionAliasesById[id] ?? "敌军"
    }

    func alias(forRegionId id: RegionId) -> String {
        regionAliasesById[id] ?? "州郡"
    }

    func resolve(_ envelope: AgentDecisionEnvelope, expectedAgentId: String) -> AgentDecisionEnvelope {
        AgentDecisionEnvelope(
            schemaVersion: envelope.schemaVersion,
            agentId: envelope.agentId == agentIdAlias ? expectedAgentId : envelope.agentId,
            turn: envelope.turn,
            intent: envelope.intent,
            orders: envelope.orders.map(resolve)
        )
    }

    private func resolve(_ order: AgentOrder) -> AgentOrder {
        let resolvedDivisionId = friendlyDivisionIdsByAlias[order.divisionId] ?? order.divisionId
        let resolvedTargetDivisionId = order.targetDivisionId.flatMap {
            enemyDivisionIdsByAlias[$0] ?? $0
        }
        let resolvedRegionId = order.toRegionId.flatMap {
            regionIdsByAlias[$0.rawValue] ?? $0
        }
        return AgentOrder(
            type: order.type,
            divisionId: resolvedDivisionId,
            to: order.to,
            toRegionId: resolvedRegionId,
            targetDivisionId: resolvedTargetDivisionId,
            stance: order.stance,
            reason: order.reason
        )
    }

    private static func chineseOrdinal(_ value: Int) -> String {
        let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        if value < digits.count {
            return digits[value]
        }
        if value == 10 {
            return "十"
        }
        if value < 20 {
            return "十\(digits[value - 10])"
        }
        if value < 100 {
            let tens = value / 10
            let ones = value % 10
            return ones == 0 ? "\(digits[tens])十" : "\(digits[tens])十\(digits[ones])"
        }
        return "\(value)"
    }
}
