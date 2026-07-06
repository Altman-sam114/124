import SwiftUI

struct AgentPanelView: View {
    let record: AgentDecisionRecord?
    let rulerRecord: RulerDecisionRecord?
    let courtRecord: CourtDecisionRecord?
    let directiveRecords: [WarDirectiveRecord]

    init(
        record: AgentDecisionRecord?,
        rulerRecord: RulerDecisionRecord? = nil,
        courtRecord: CourtDecisionRecord? = nil,
        directiveRecords: [WarDirectiveRecord] = []
    ) {
        self.record = record
        self.rulerRecord = rulerRecord
        self.courtRecord = courtRecord
        self.directiveRecords = directiveRecords
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("朝堂决策")
                .font(.headline)

            LabeledContent("决策者") {
                Text(displayAgentName(record?.agentId))
            }

            LabeledContent("来源") {
                Text(displayProviderName(record?.provider))
            }

            LabeledContent("意图") {
                Text(displayDiagnosticText(record?.parsedIntent ?? "暂无决策"))
                    .multilineTextAlignment(.trailing)
            }

            if let contextSummary = record?.contextSummary {
                LabeledContent("态势") {
                    Text(displayDiagnosticText(contextSummary))
                        .multilineTextAlignment(.trailing)
                }
            }

            if let rulerRecord {
                Divider()
                LabeledContent("君主") {
                    Text(displayAgentName(rulerRecord.rulerAgentId))
                }
                LabeledContent("姿态") {
                    Text(rulerRecord.posture.displayName)
                }
                if let zoneId = rulerRecord.preferredFrontZoneId {
                    LabeledContent("重点") {
                        Text(displayFrontZoneName(zoneId))
                    }
                }
            }

            if let courtRecord {
                Divider()
                Text("朝堂链路")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(courtRecord.steps) { step in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(step.role.displayName)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(PlatformStyles.selectionTint)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Text(displayAgentName(step.agentId))
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }

                            Text(displayDiagnosticText(step.summary))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(courtStepDetail(step))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .suitangPanel(.inset)
                    }
                }
            }

            if let record, !record.commandResults.isEmpty {
                Text("军令结果")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(record.commandResults) { result in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayDiagnosticText(result.commandDisplayName ?? orderTypeDisplayName(result.orderType)))
                                .font(.caption)
                                .bold()
                            Text(resultLine(result))
                                .font(.caption)
                                .foregroundStyle(result.executed ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if !directiveRecords.isEmpty {
                Text("方面军令")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(directiveRecords) { directive in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(directive.zoneId.map(displayFrontZoneName) ?? "全局")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(PlatformStyles.selectionTint)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                Text(directiveSummary(directive))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }

                            if !directive.diagnostics.isEmpty {
                                Text(directive.diagnostics.map(displayDiagnosticText).joined(separator: "；"))
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .suitangPanel(.inset)
                    }
                }
            }

            if let record, !record.errors.isEmpty {
                Text("问题")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(record.errors, id: \.self) { error in
                        Text(displayDiagnosticText(error))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

        }
        .suitangPanel()
    }

    private func directiveSummary(_ directive: WarDirectiveRecord) -> String {
        let type = directive.directiveType?.displayName ?? "军情说明"
        let tactic = directive.tactic?.displayName ?? directive.category?.displayName ?? "无"
        let executed = directive.commandResults.filter(\.executed).count
        let rejected = directive.commandResults.count - executed
        let targetText = directive.targetRegionIds.isEmpty ? "无目标" : "目标 \(directive.targetRegionIds.count) 处"
        return "\(type)，\(tactic)，成功 \(executed)，拒绝 \(rejected)，\(targetText)"
    }

    private func displayProviderName(_ provider: String?) -> String {
        guard let provider, !provider.isEmpty else {
            return "本地模拟朝堂"
        }

        let normalized = provider.lowercased()
        if normalized.contains("marshaldirective") {
            return "军议"
        }
        if normalized.contains("directive") {
            return "方面军令"
        }
        if normalized.contains("mock") {
            return "本地模拟朝堂"
        }
        if normalized.contains("local") {
            return "本地军议来源"
        }
        return "朝堂系统"
    }

    private func courtStepDetail(_ step: CourtAgentStepRecord) -> String {
        let zoneText = step.targetZoneIds.isEmpty ? "无方面" : "方面 \(step.targetZoneIds.count) 处"
        let regionText = step.targetRegionIds.isEmpty ? "无州郡" : "州郡 \(step.targetRegionIds.count) 处"
        return "指令 \(step.directiveCount)，\(zoneText)，\(regionText)"
    }

    private func resultLine(_ result: CommandResultSummary) -> String {
        if !result.mappingSucceeded {
            return "军令转换失败。"
        }

        if result.executed {
            return displayDiagnosticText(result.message)
        }

        if !result.errors.isEmpty {
            return "被拒绝：\(result.errors.map(displayDiagnosticText).joined(separator: "；"))"
        }

        return displayDiagnosticText(result.message)
    }

    private func displayDiagnosticText(_ text: String) -> String {
        return sanitizeRawIdentifiers(in: text)
            .replacingOccurrences(of: "Heinz Guderian", with: "历史总管")
            .replacingOccurrences(of: "Guderian", with: "历史总管")
            .replacingOccurrences(of: "Field Marshal", with: "行军总管")
            .replacingOccurrences(of: "Army Commander", with: "行军总管")
            .replacingOccurrences(of: "Ruler", with: "君主")
            .replacingOccurrences(of: "rawJSON", with: "军情记录")
            .replacingOccurrences(of: "rawJson", with: "军情记录")
            .replacingOccurrences(of: "raw JSON", with: "军情记录")
            .replacingOccurrences(of: "raw json", with: "军情记录")
            .replacingOccurrences(of: "JSON", with: "军情记录")
            .replacingOccurrences(of: "json", with: "军情记录")
            .replacingOccurrences(of: "Schema", with: "格式")
            .replacingOccurrences(of: "schema", with: "格式")
            .replacingOccurrences(of: "Provider", with: "来源")
            .replacingOccurrences(of: "provider", with: "来源")
            .replacingOccurrences(of: "local-model", with: "本地军议来源")
            .replacingOccurrences(of: "Model", with: "军议来源")
            .replacingOccurrences(of: "model", with: "军议来源")
            .replacingOccurrences(of: "OpenAI", with: "外部军议来源")
            .replacingOccurrences(of: "GPT", with: "外部军议来源")
            .replacingOccurrences(of: "Claude", with: "外部军议来源")
            .replacingOccurrences(of: "Gemini", with: "外部军议来源")
            .replacingOccurrences(of: "LLM", with: "军议来源")
            .replacingOccurrences(of: "ZoneDirective", with: "方面军令")
            .replacingOccurrences(of: "WarDeploymentState", with: "行军部署")
            .replacingOccurrences(of: "FrontZone", with: "行军防区")
            .replacingOccurrences(of: "Division", with: "军队")
            .replacingOccurrences(of: "Legacy Pipeline", with: "备用军议路径")
            .replacingOccurrences(of: "Legacy pipeline", with: "备用军议路径")
            .replacingOccurrences(of: "legacy pipeline", with: "备用军议路径")
            .replacingOccurrences(of: "Pipeline", with: "军议路径")
            .replacingOccurrences(of: "pipeline", with: "军议路径")
            .replacingOccurrences(of: "Fallback", with: "备用处置")
            .replacingOccurrences(of: "fallback", with: "备用处置")
            .replacingOccurrences(of: "Command", with: "命令")
            .replacingOccurrences(of: "RuleEngine", with: "军令校验")
            .replacingOccurrences(of: "Record", with: "记录")
            .replacingOccurrences(of: "record", with: "记录")
            .replacingOccurrences(of: "MockAI", with: "本地模拟朝堂")
            .replacingOccurrences(of: "AI", with: "军议")
            .replacingOccurrences(of: "Agent", with: "朝堂成员")
            .replacingOccurrences(of: "agent", with: "朝堂成员")
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

    private func orderTypeDisplayName(_ orderType: AgentOrderType?) -> String {
        guard let orderType else {
            return "指令"
        }
        switch orderType {
        case .move:
            return "移动"
        case .attack:
            return "进攻"
        case .hold:
            return "坚守"
        case .resupply:
            return "补给"
        }
    }

    private func displayAgentName(_ agentId: String?) -> String {
        guard let agentId, !agentId.isEmpty else {
            return "本地总管"
        }

        let normalized = agentId
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()

        if normalized.contains("ruler") || normalized.contains("sovereign") {
            return "君主"
        }
        if normalized.contains("strategist") || normalized.contains("marshal") {
            return "谋主"
        }
        if normalized.contains("governor") {
            return "太守"
        }
        if normalized.contains("diplomat") {
            return "使者"
        }
        if normalized.contains("march") || normalized.contains("commander") || normalized.contains("guderian") {
            return "行军总管"
        }
        if normalized.contains("mock") {
            return "本地模拟朝堂"
        }
        return "朝堂成员"
    }

    private func displayFrontZoneName(_ zoneId: FrontZoneId) -> String {
        zoneId.rawValue.isEmpty ? "方面" : "重点方面"
    }
}
