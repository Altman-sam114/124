import SwiftUI

struct DiplomacyPanelView: View {
    let diplomacyState: DiplomacyState
    let activeFaction: Faction
    let diplomacyTarget: Faction?
    let submissionPresenceSummaries: [SubmissionPresenceSummary]
    let canResolveSubmissionHandoff: (Faction) -> Bool
    let canIssueDiplomacy: Bool
    let onProposeTruce: () -> Void
    let onAcceptSubmission: () -> Void
    let onResolveSubmissionHandoff: (Faction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("外交")
                .font(.headline)

            if let rulerRecord = diplomacyState.latestRulerRecord {
                rulerSection(rulerRecord)
                Divider()
            }

            if let courtRecord = diplomacyState.latestCourtRecord {
                courtSection(courtRecord)
                Divider()
            }

            countrySection
            Divider()
            blocSection
            Divider()
            relationSection
            Divider()
            diplomacyEventSection
            Divider()
            submissionHandoffSection
            Divider()
            submissionAftermathSection
            Divider()
            submissionPresenceSection
            Divider()
            actionSection
        }
        .suitangPanel()
    }

    private var countrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("势力")
                .font(.subheadline.weight(.semibold))

            ForEach(diplomacyState.countries) { country in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(countryDisplayName(country))
                            .font(.caption.weight(.semibold))
                        Text("\(country.faction.displayName)，\(blocDisplayName(for: country.blocId))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(country.warSupport)")
                            .font(.caption.monospacedDigit())
                        Text("战意")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(country.faction == activeFaction ? .primary : .secondary)
                }
            }
        }
    }

    private var blocSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("盟从")
                .font(.subheadline.weight(.semibold))

            ForEach(diplomacyState.blocs) { bloc in
                LabeledContent(blocDisplayName(bloc)) {
                    Text("\(bloc.memberCountryIds.count) 方")
                        .foregroundStyle(bloc.faction == activeFaction ? .primary : .secondary)
                }
                .font(.caption)
            }
        }
    }

    private var relationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("关系")
                .font(.subheadline.weight(.semibold))

            if diplomacyState.relations.isEmpty {
                Text("暂无外交关系。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(diplomacyState.relations) { relation in
                    HStack {
                        Text(relationPartiesText(relation))
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text(relation.status.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(relation.status.isHostile ? .red : .secondary)
                    }
                }
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("使者")
                .font(.subheadline.weight(.semibold))

            if let diplomacyTarget {
                LabeledContent("对象") {
                    Text(diplomacyTarget.displayName)
                }
                .font(.caption)

                HStack(spacing: 8) {
                    Button("议和", systemImage: "scroll", action: onProposeTruce)
                        .disabled(!canIssueDiplomacy)
                    Button("纳降", systemImage: "seal", action: onAcceptSubmission)
                        .disabled(!canIssueDiplomacy)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: SuitangDesignTokens.minimumTapTarget)
            } else {
                Text("暂无敌对对象可议。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("使者只调整外交关系，州郡与军队另行处置。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var diplomacyEventSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("事件")
                .font(.subheadline.weight(.semibold))

            if let record = diplomacyState.latestDiplomacyEventRecord {
                LabeledContent("最近") {
                    Text(displayRecordText(record.summary))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
                LabeledContent("回合") {
                    Text("\(record.turn)")
                        .monospacedDigit()
                }
                Text(displayBoundaryNote(record.boundaryNote))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("暂无外交事件记录。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private var submissionPresenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("归附实体")
                .font(.subheadline.weight(.semibold))

            if submissionPresenceSummaries.isEmpty {
                Text("暂无归附势力实体盘点。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(submissionPresenceSummaries) { summary in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(summary.faction.displayName)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(summary.presenceText)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Label(
                                summary.turnOrderText,
                                systemImage: summary.hasRuntimePresence ? "exclamationmark.triangle" : "checkmark.seal"
                            )
                            .font(.caption)
                            .foregroundStyle(summary.hasRuntimePresence ? SuitangDesignTokens.copper : SuitangDesignTokens.jade)
                            .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 8)

                            if summary.hasRuntimePresence {
                                Button("接管", systemImage: "arrow.triangle.merge") {
                                    onResolveSubmissionHandoff(summary.faction)
                                }
                                .disabled(!canResolveSubmissionHandoff(summary.faction))
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }
        }
    }

    private var submissionHandoffSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("交接")
                .font(.subheadline.weight(.semibold))

            if let record = diplomacyState.latestSubmissionHandoffRecord {
                LabeledContent("最近") {
                    Text(displayRecordText(record.summary))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
                LabeledContent("州郡") {
                    Text(record.affectedRegionIds.isEmpty ? "无" : "\(record.affectedRegionIds.count) 处")
                        .monospacedDigit()
                }
                LabeledContent("回合") {
                    Text("\(record.turn)")
                        .monospacedDigit()
                }
                Text(displayBoundaryNote(record.boundaryNote))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("暂无归附交接记录。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private var submissionAftermathSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("善后")
                .font(.subheadline.weight(.semibold))

            if let record = diplomacyState.latestSubmissionAftermathRecord {
                let governanceRecords = diplomacyState.submissionAftermathGovernanceRecords(linkedTo: record.id)
                let governedRegionCount = diplomacyState.governedAftermathRegionCount(
                    linkedTo: record.id,
                    affectedRegionIds: record.affectedRegionIds
                )
                let ungovernedRegionCount = diplomacyState.ungovernedAftermathRegionCount(
                    linkedTo: record.id,
                    affectedRegionIds: record.affectedRegionIds
                )
                let isGovernanceComplete = diplomacyState.isAftermathGovernanceComplete(
                    linkedTo: record.id,
                    affectedRegionIds: record.affectedRegionIds
                )

                LabeledContent("压力") {
                    Text(record.riskLevel.displayName)
                        .fontWeight(.semibold)
                }
                LabeledContent("最近") {
                    Text(displayRecordText(record.summary))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
                LabeledContent("州郡") {
                    Text(record.affectedRegionIds.isEmpty ? "无" : "\(record.affectedRegionIds.count) 处")
                        .monospacedDigit()
                }
                LabeledContent("回合") {
                    Text("\(record.turn)")
                        .monospacedDigit()
                }
                LabeledContent("处置进度") {
                    Text(aftercareProgressText(
                        governedRegionCount: governedRegionCount,
                        affectedRegionCount: record.affectedRegionIds.count
                    ))
                    .monospacedDigit()
                }
                LabeledContent("待处置") {
                    Text(aftercarePendingText(
                        ungovernedRegionCount: ungovernedRegionCount,
                        affectedRegionCount: record.affectedRegionIds.count
                    ))
                    .monospacedDigit()
                }
                LabeledContent("状态") {
                    Text(aftercareStatusText(
                        isGovernanceComplete: isGovernanceComplete,
                        affectedRegionCount: record.affectedRegionIds.count
                    ))
                    .multilineTextAlignment(.trailing)
                }
                Text(displayBoundaryNote(record.boundaryNote))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let governanceRecord = governanceRecords.last {
                    LabeledContent("处置") {
                        Text(displayRecordText(governanceRecord.summary))
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                    }
                    LabeledContent("处置回合") {
                        Text("\(governanceRecord.turn)")
                            .monospacedDigit()
                    }
                    Text(displayBoundaryNote(governanceRecord.boundaryNote))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("尚无本次善后处置记录。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("暂无归附善后记录。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private func aftercareProgressText(governedRegionCount: Int, affectedRegionCount: Int) -> String {
        guard affectedRegionCount > 0 else {
            return "无州郡"
        }
        return "\(governedRegionCount) 处已处置，共 \(affectedRegionCount) 处"
    }

    private func aftercarePendingText(ungovernedRegionCount: Int, affectedRegionCount: Int) -> String {
        guard affectedRegionCount > 0 else {
            return "无州郡"
        }
        return "\(ungovernedRegionCount) 处"
    }

    private func aftercareStatusText(isGovernanceComplete: Bool, affectedRegionCount: Int) -> String {
        guard affectedRegionCount > 0 else {
            return "无受影响州郡"
        }
        return isGovernanceComplete ? "已全部处置" : "仍需处置"
    }

    private func rulerSection(_ record: RulerDecisionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("君主")
                .font(.subheadline.weight(.semibold))
            LabeledContent("决策者") {
                Text(agentDisplayName(record.rulerAgentId, fallbackRole: "君主"))
            }
            LabeledContent("姿态") {
                Text(record.posture.displayName)
            }
            if let zoneId = record.preferredFrontZoneId {
                LabeledContent("重点") {
                    Text(frontZoneDisplayText(zoneId))
                }
            }
            Text(displayRecordText(record.rationale))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func courtSection(_ record: CourtDecisionRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("朝堂")
                .font(.subheadline.weight(.semibold))
            LabeledContent("谋主") {
                Text(agentDisplayName(record.strategistAgentId, fallbackRole: "谋主"))
            }
            LabeledContent("军令") {
                Text("\(record.directiveCount) 条")
            }
            if let diplomat = record.steps.first(where: { $0.role == .diplomat }) {
                LabeledContent("使者") {
                    Text(displayRecordText(diplomat.summary))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
            }
        }
        .font(.caption)
    }

    private func blocDisplayName(for blocId: DiplomaticBlocId) -> String {
        guard let bloc = diplomacyState.blocs.first(where: { $0.id == blocId }) else {
            return "未编入盟从"
        }
        return blocDisplayName(bloc)
    }

    private func displayBoundaryNote(_ note: String) -> String {
        if note.contains("归附事件") {
            return "归附已记入外交档案；州郡、军队和战线仍按后续军情另行处置。"
        }
        if note.contains("停战事件") {
            return "停战已记入外交档案；既有驻防和占领保持当前局势。"
        }
        if note.contains("交接记录") {
            return "本记录说明本次交接结果，后续安置仍需另行处理。"
        }
        if note.contains("善后压力") {
            return "本记录提示后续安民、整军或道路粮仓治理重点。"
        }
        if note.contains("善后处置") {
            return "本记录说明本次州郡处置结果，后续安置仍需继续观察。"
        }
        return "外交变化已记入档案；战场局势仍按后续行动推进。"
    }

    private func displayRecordText(_ text: String) -> String {
        sanitizeRawIdentifiers(in: text)
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
            .replacingOccurrences(of: "source", with: "来源")
            .replacingOccurrences(of: "intent", with: "意图")
            .replacingOccurrences(of: "reason", with: "理由")
            .replacingOccurrences(of: "stance", with: "姿态")
            .replacingOccurrences(of: "local-model", with: "本地军议来源")
            .replacingOccurrences(of: "Model", with: "军议来源")
            .replacingOccurrences(of: "model", with: "军议来源")
            .replacingOccurrences(of: "OpenAI", with: "外部军议来源")
            .replacingOccurrences(of: "GPT", with: "外部军议来源")
            .replacingOccurrences(of: "Claude", with: "外部军议来源")
            .replacingOccurrences(of: "Gemini", with: "外部军议来源")
            .replacingOccurrences(of: "LLM", with: "军议来源")
            .replacingOccurrences(of: "Field Marshal", with: "行军总管")
            .replacingOccurrences(of: "Army Commander", with: "行军总管")
            .replacingOccurrences(of: "Command", with: "命令")
            .replacingOccurrences(of: "command", with: "命令")
            .replacingOccurrences(of: "RuleEngine", with: "军令校验")
            .replacingOccurrences(of: "ZoneDirective", with: "方面军令")
            .replacingOccurrences(of: "WarDeploymentState", with: "行军部署")
            .replacingOccurrences(of: "FrontZone", with: "行军防区")
            .replacingOccurrences(of: "Division", with: "军队")
            .replacingOccurrences(of: "directive", with: "军令")
            .replacingOccurrences(of: "Legacy Pipeline", with: "备用军议路径")
            .replacingOccurrences(of: "Legacy pipeline", with: "备用军议路径")
            .replacingOccurrences(of: "legacy pipeline", with: "备用军议路径")
            .replacingOccurrences(of: "Pipeline", with: "军议路径")
            .replacingOccurrences(of: "pipeline", with: "军议路径")
            .replacingOccurrences(of: "Record", with: "记录")
            .replacingOccurrences(of: "record", with: "记录")
            .replacingOccurrences(of: "MockAI", with: "本地模拟朝堂")
            .replacingOccurrences(of: "AI", with: "军议")
            .replacingOccurrences(of: "Agent", with: "朝堂成员")
            .replacingOccurrences(of: "agent", with: "朝堂成员")
            .replacingOccurrences(of: "Heinz Guderian", with: "历史总管")
            .replacingOccurrences(of: "Guderian", with: "历史总管")
            .replacingOccurrences(of: "Fallback", with: "备用处置")
            .replacingOccurrences(of: "fallback", with: "备用处置")
            .replacingOccurrences(of: "Diagnostic", with: "军情说明")
            .replacingOccurrences(of: "diagnostic", with: "军情说明")
            .replacingOccurrences(of: "breakthrough", with: "突破")
            .replacingOccurrences(of: "Region", with: "州郡")
            .replacingOccurrences(of: "region", with: "州郡")
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
                of: #"\bcourt_decision_[A-Za-z0-9_\-]+\b"#,
                with: "朝堂记录",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bcourt_[A-Za-z0-9_\-]+_turn_[0-9]+\b"#,
                with: "朝堂记录",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bcourt_[0-9]+_[A-Za-z0-9_\-]+\b"#,
                with: "朝堂记录",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bruler_decision_[A-Za-z0-9_\-]+\b"#,
                with: "君主记录",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\bruler_[A-Za-z0-9_\-]+_turn_[A-Za-z0-9_\-]+\b"#,
                with: "君主记录",
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

    private func blocDisplayName(_ bloc: DiplomaticBloc) -> String {
        switch bloc.id.rawValue {
        case "axis":
            return "历史军盟"
        case "allied_coalition":
            return "历史同盟"
        default:
            if bloc.name.isEmpty || containsLatinLetters(bloc.name) {
                return bloc.faction.displayName
            }
            return bloc.name
        }
    }

    private func relationPartiesText(_ relation: DiplomaticRelation) -> String {
        "\(countryDisplayName(for: relation.firstCountryId)) 与 \(countryDisplayName(for: relation.secondCountryId))"
    }

    private func countryDisplayName(for countryId: CountryId) -> String {
        guard let country = diplomacyState.countries.first(where: { $0.id == countryId }) else {
            return "未知势力"
        }
        return countryDisplayName(country)
    }

    private func countryDisplayName(_ country: CountryProfile) -> String {
        switch country.id.rawValue {
        case "germany":
            return "历史势力"
        case "united_states":
            return "历史盟友"
        case "united_kingdom":
            return "历史盟友"
        case "belgium":
            return "地方盟友"
        default:
            if country.name.isEmpty || containsLatinLetters(country.name) {
                return country.faction.displayName
            }
            return country.name
        }
    }

    private func containsLatinLetters(_ text: String) -> Bool {
        text.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
    }

    private func agentDisplayName(_ agentId: String, fallbackRole: String) -> String {
        switch agentId {
        case "sovereign_li_yuan":
            return "李渊"
        case "sovereign_wang_shichong":
            return "王世充"
        case "sovereign_li_mi":
            return "李密"
        case "sovereign_dou_jiande":
            return "窦建德"
        case "sovereign_xue_ju":
            return "薛举"
        case "sovereign_liu_wuzhou":
            return "刘武周"
        case "sovereign_tujue":
            return "东突厥可汗"
        case "strategist_li_shimin":
            return "李世民"
        case "strategist_wang_shichong":
            return "王世充"
        case "strategist_li_mi":
            return "李密"
        case "strategist_dou_jiande":
            return "窦建德"
        case "ruler_germany":
            return "历史统帅"
        case "ruler_allies":
            return "历史议事会"
        case "ruler_uk":
            return "历史议事"
        case "ruler_belgium":
            return "地方代表"
        default:
            if agentId.hasPrefix("sovereign_") || agentId.hasPrefix("ruler_") {
                return fallbackRole
            }
            if agentId.hasPrefix("strategist_") {
                return "谋主"
            }
            if agentId.hasPrefix("governor_staff_") {
                return "太守署"
            }
            if agentId.hasPrefix("march_commander_") {
                return "行军总管"
            }
            if agentId.hasPrefix("general_staff_") {
                return "将领幕府"
            }
            if agentId.hasPrefix("diplomat_") {
                return "使者署"
            }
            return fallbackRole
        }
    }

    private func frontZoneDisplayText(_ zoneId: FrontZoneId) -> String {
        zoneId.rawValue.isEmpty ? "已指定防区" : "已指定重点防区"
    }
}
