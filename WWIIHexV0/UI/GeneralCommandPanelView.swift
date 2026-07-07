import SwiftUI

struct GeneralCommandPanelView: View {
    let zone: FrontZone?
    let general: GeneralData?
    let assignment: GeneralAssignment?
    let assignedDivisions: [Division]
    let targetRegion: RegionNode?
    let targetZone: FrontZone?
    let hqUnderAttack: Bool
    let plannedOperations: [PlayerPlannedOperation]
    let canHoldLine: Bool
    let canAttackRegion: Bool
    let onShowProfile: () -> Void
    let onHoldLine: () -> Void
    let onAttackRegion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("总管军令")
                .font(.headline)

            if let zone {
                LabeledContent("行军防区") {
                    Text(displayZoneName(zone))
                        .multilineTextAlignment(.trailing)
                }
            } else {
                Text("未选择己方行军防区。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let general {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        Button(action: onShowProfile) {
                            portraitBadge(for: general)
                        }
                            .accessibilityLabel("查看 \(displayGeneralName(general)) 档案")
                            .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayGeneralName(general))
                                .font(.subheadline.weight(.semibold))
                            Text("\(displayGeneralRank(general.rank))，\(styleLabel(general.commandStyle))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(displayGeneralText(general.biography, fallback: "暂无履历。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    if !general.skills.isEmpty {
                        Text(general.skills.map(skillDisplayName).joined(separator: "、"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let assignment {
                        metricBar(title: "忠诚", value: assignment.loyalty)
                        metricBar(title: "满意", value: assignment.satisfaction)
                        LabeledContent("干预") {
                            Text("\(assignment.interventionCount)")
                        }
                    }

                    Button("查看档案", systemImage: "person.text.rectangle", action: onShowProfile)
                        .buttonStyle(.bordered)
                }
            } else if zone != nil {
                Text("该防区尚未任命总管。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if hqUnderAttack {
                Label("本营州郡受压", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            if !assignedDivisions.isEmpty {
                Text("所属军队")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(assignedDivisions.prefix(5)), id: \.id) { division in
                        Label(displayDivisionName(division), systemImage: unitIcon(for: division))
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }

            if let targetRegion, targetZone?.faction != zone?.faction {
                LabeledContent("目标") {
                    Text(displayRegionName(targetRegion.name))
                }
            }

            HStack(spacing: 8) {
                Button("固守", systemImage: "shield.fill", action: onHoldLine)
                    .disabled(!canHoldLine)
                Button("进军", systemImage: "arrow.up.right.circle", action: onAttackRegion)
                    .disabled(!canAttackRegion)
            }
            .buttonStyle(.bordered)

            if !plannedOperations.isEmpty {
                Text("预备军令")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plannedOperations) { operation in
                        Label(operationSummary(operation), systemImage: operationIcon(operation))
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
            }
        }
        .suitangPanel()
    }

    private func portraitBadge(for general: GeneralData) -> some View {
        Text(initials(for: displayGeneralName(general)))
            .font(.caption.weight(.bold))
            .frame(width: 40, height: 40)
            .background(SuitangDesignTokens.cinnabar.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("\(displayGeneralName(general)) 头像")
    }

    private func metricBar(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)")
            }
            .font(.caption)
            ProgressView(value: Double(value), total: 100)
                .tint(value >= 65 ? .green : value >= 40 ? .orange : .red)
        }
    }

    private func initials(for name: String) -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return "将"
        }
        return String(name.prefix(2))
    }

    private func styleLabel(_ style: ZoneCommanderAgentConfig.CommandStyle) -> String {
        switch style {
        case .aggressive:
            return "锐进"
        case .balanced:
            return "持重"
        case .cautious:
            return "谨慎"
        }
    }

    private func skillDisplayName(_ skill: String) -> String {
        generalSkillDisplayName(skill)
    }

    private func unitIcon(for division: Division) -> String {
        if division.hasSiegeCapability {
            return "scope"
        }
        if division.hasCavalryShock {
            return "flag.fill"
        }
        return "person.3.fill"
    }

    private func operationIcon(_ operation: PlayerPlannedOperation) -> String {
        operation.directiveType == .attack ? "arrow.up.right.circle" : "shield.fill"
    }

    private func operationSummary(_ operation: PlayerPlannedOperation) -> String {
        let target = operationTargetLabel(operation)
        let type = operation.directiveType.displayName
        return "\(type)：\(target)"
    }

    private func operationTargetLabel(_ operation: PlayerPlannedOperation) -> String {
        if operation.targetRegionId == targetRegion?.id, let targetRegion {
            return displayRegionName(targetRegion.name)
        }
        if operation.targetRegionId != nil {
            return "目标州郡"
        }
        if operation.sourceRegionId != nil {
            return "本防区州郡"
        }
        return zone.map(displayZoneName) ?? "本防区"
    }

    private func displayZoneName(_ zone: FrontZone) -> String {
        guard !zone.name.isEmpty,
              !zone.name.contains("_"),
              !zone.name.hasPrefix("theater"),
              !zone.name.hasPrefix("front"),
              zone.name != zone.id.rawValue else {
            return "行军防区"
        }
        return displayGeneralText(zone.name, fallback: "行军防区")
    }

    private func displayGeneralName(_ general: GeneralData) -> String {
        displayGeneralText(general.localizedName, fallback: "将领")
    }

    private func displayGeneralRank(_ rank: String) -> String {
        let text = displayGeneralText(rank, fallback: "将领")
        return text
            .replacingOccurrences(of: "Field Marshal", with: "行军总管")
            .replacingOccurrences(of: "Army Commander", with: "行军总管")
            .replacingOccurrences(of: "General", with: "将领")
    }

    private func displayDivisionName(_ division: Division) -> String {
        let trimmed = division.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "\(displayFactionName(division.faction))\(division.unitKindDisplayName)"
        guard !trimmed.isEmpty else {
            return displayGeneralText(fallback, fallback: "军队")
        }
        return displayGeneralText(trimmed, fallback: fallback)
    }

    private func displayRegionName(_ name: String) -> String {
        displayGeneralText(name, fallback: "目标州郡")
    }

    private func displayGeneralText(_ text: String, fallback: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallback
        }

        let sanitized = trimmed
            .replacingOccurrences(
                of: #"\b(general|agent|commander|front_zone|theater|region|objective|obj|hex|war_directive|player_directive|player_operation|court_decision|ruler_decision|division|unit)_[A-Za-z0-9_\-]+\b"#,
                with: fallback,
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(ger|all|allied|axis|germany|france)_[A-Za-z0-9_\-]+\b"#,
                with: fallback,
                options: .regularExpression
            )
            .replacingOccurrences(of: "Heinz Guderian", with: "历史总管")
            .replacingOccurrences(of: "HEINZ GUDERIAN", with: "历史总管")
            .replacingOccurrences(of: "heinz guderian", with: "历史总管")
            .replacingOccurrences(of: "Guderian", with: "历史总管")
            .replacingOccurrences(of: "guderian", with: "历史总管")
            .replacingOccurrences(of: "古德里安", with: "历史总管")
            .replacingOccurrences(of: "Field Marshal", with: "行军总管")
            .replacingOccurrences(of: "Army Commander", with: "行军总管")
            .replacingOccurrences(of: "Panzer", with: "甲骑")
            .replacingOccurrences(of: "PANZER", with: "甲骑")
            .replacingOccurrences(of: "panzer", with: "甲骑")
            .replacingOccurrences(of: "armor", with: "突击")
            .replacingOccurrences(of: "Armor", with: "突击")
            .replacingOccurrences(of: "ARMOR", with: "突击")
            .replacingOccurrences(of: "breakthrough", with: "破阵")
            .replacingOccurrences(of: "Ardennes", with: "旧战局")
            .replacingOccurrences(of: "ardennes", with: "旧战局")
            .replacingOccurrences(of: "Bastogne", with: "旧战局要地")
            .replacingOccurrences(of: "bastogne", with: "旧战局要地")
            .replacingOccurrences(of: "St. Vith", with: "旧战局要地")
            .replacingOccurrences(of: "St Vith", with: "旧战局要地")
            .replacingOccurrences(of: "Sedan", with: "旧战局要地")
            .replacingOccurrences(of: "sedan", with: "旧战局要地")
            .replacingOccurrences(of: "阿登", with: "旧战局")
            .replacingOccurrences(of: "巴斯托涅", with: "旧战局要地")
            .replacingOccurrences(of: "圣维特", with: "旧战局要地")
            .replacingOccurrences(of: "德军", with: "旧剧本")
            .replacingOccurrences(of: "盟军", with: "旧剧本")
            .replacingOccurrences(of: "装甲", with: "甲骑")
            .replacingOccurrences(of: "摩托化", with: "骑军")
            .replacingOccurrences(of: "炮兵", with: "弓弩")
            .replacingOccurrences(of: "步兵", with: "步卒")
            .replacingOccurrences(of: "师", with: "军")

        return sanitized.isEmpty ? fallback : sanitized
    }

    private func displayFactionName(_ faction: Faction) -> String {
        switch faction {
        case .germany, .allies:
            return "旧剧本势力"
        default:
            return faction.displayName
        }
    }
}

func generalSkillDisplayName(_ skill: String) -> String {
    switch skill {
    case "army_group_coordination":
        return "集团协同"
    case "armor_expert", "armor_theory":
        return "突击战法"
    case "border_pressure":
        return "边境施压"
    case "breakthrough":
        return "破阵"
    case "capital_defense":
        return "京畿守备"
    case "cautious":
        return "谨慎"
    case "cavalry_charge", "cavalry_command", "cavalry_shock", "shock_cavalry":
        return "骑军突击"
    case "coalition_coordination":
        return "联军协同"
    case "counterattack":
        return "反击"
    case "court_intrigue":
        return "朝局权谋"
    case "decisive_battle":
        return "决战"
    case "defensive_formation", "defensive_master":
        return "固阵"
    case "diplomatic_leverage":
        return "外交施压"
    case "disciplined_retreat":
        return "有序退却"
    case "field_army":
        return "野战军略"
    case "fortress_defense", "fortress_operations":
        return "坚城防务"
    case "frontier_supply":
        return "边地粮道"
    case "frontline_coordination":
        return "方面协同"
    case "governance":
        return "安州郡"
    case "granary_control", "granary_warfare":
        return "控仓"
    case "hebei_logistics":
        return "河北转运"
    case "heluo_control":
        return "河洛经略"
    case "insurgent_mobilization":
        return "义军动员"
    case "local_coordination":
        return "地方协同"
    case "logistics":
        return "粮道筹划"
    case "morale":
        return "振士气"
    case "mountain_route":
        return "山道行军"
    case "northern_cavalry":
        return "北地骑军"
    case "offensive_planning":
        return "攻势筹划"
    case "operational_mobility", "rapid_exploitation", "rapid_march":
        return "机动扩张"
    case "political_weight", "political_will":
        return "政治威望"
    case "popular_support":
        return "民望"
    case "pressure_management":
        return "接敌施压"
    case "raiding":
        return "袭扰"
    case "reserve_control", "reserve_coordination":
        return "预备队调度"
    case "river_crossing":
        return "渡河"
    case "screening_force":
        return "掩护部队"
    case "set_piece_attack":
        return "阵地攻势"
    case "siegecraft":
        return "攻城"
    case "staff_coordination":
        return "幕府参谋"
    case "taiyuan_pressure":
        return "太原施压"
    case "western_pressure":
        return "西线压迫"
    case "winter_campaign":
        return "冬季行军"
    case "aggressive":
        return "锐进"
    default:
        return "未列军略"
    }
}
