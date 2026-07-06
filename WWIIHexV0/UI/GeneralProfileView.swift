import SwiftUI

struct GeneralProfileView: View {
    let general: GeneralData
    let assignment: GeneralAssignment?
    let zone: FrontZone?
    let assignedDivisions: [Division]
    let hqUnderAttack: Bool
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    identityBlock
                    VStack(alignment: .leading, spacing: 12) {
                        biographyBlock
                        statusBlock
                    }
                }

                skillsBlock
                assignedUnitsBlock
            }
            .padding(18)
        }
        .background(SuitangDesignTokens.elevatedPanelBackground)
        .safeAreaInset(edge: .top) {
            HStack {
                Text("将领档案")
                    .font(.headline)
                Spacer()
                Button("关闭", systemImage: "xmark", action: onClose)
                    .buttonStyle(.bordered)
                    .frame(minHeight: SuitangDesignTokens.minimumTapTarget)
            }
            .suitangPanel(.elevated)
        }
    }

    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(initials)
                .font(.title.weight(.bold))
                .frame(width: 112, height: 144)
                .background(SuitangDesignTokens.cinnabar.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("\(displayName) 画像")

            Text(displayName)
                .font(.title3.weight(.semibold))
            Text(displayGeneralRank(general.rank))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(displayFactionName(general.faction))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(SuitangDesignTokens.insetBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(minWidth: 132, alignment: .leading)
    }

    private var biographyBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("生平")
                .font(.headline)
            Text(displayGeneralText(general.biography, fallback: "暂无履历。"))
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent("用兵") {
                Text(styleLabel(general.commandStyle))
            }
            if let zone {
                LabeledContent("所属防区") {
                    Text(displayZoneName(zone))
                        .multilineTextAlignment(.trailing)
                }
            }
            if hqUnderAttack {
                Label("本营州郡受压", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("亲附")
                .font(.headline)
            metricBar(title: "忠诚", value: assignment?.loyalty ?? general.baseLoyalty)
            metricBar(title: "满意", value: assignment?.satisfaction ?? general.baseSatisfaction)
            LabeledContent("干预") {
                Text("\(assignment?.interventionCount ?? 0)")
            }
        }
    }

    private var skillsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("特性")
                .font(.headline)
            if general.skills.isEmpty {
                Text("暂无特性。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(general.skills, id: \.self) { skill in
                        Label(skillDisplayName(skill), systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(SuitangDesignTokens.insetBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private var assignedUnitsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("所属军队")
                .font(.headline)
            if assignedDivisions.isEmpty {
                Text("暂无所属军队。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(assignedDivisions, id: \.id) { division in
                    LabeledContent(displayDivisionName(division)) {
                        Text("兵力 \(division.strength)，上限 \(division.maxStrength)")
                    }
                    .font(.caption)
                }
            }
        }
    }

    private func metricBar(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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

    private var initials: String {
        let words = displayName.split(separator: " ")
        let letters = words.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "将" : String(letters).uppercased()
    }

    private var displayName: String {
        displayGeneralText(general.localizedName, fallback: "将领")
    }

    private func skillDisplayName(_ skill: String) -> String {
        generalSkillDisplayName(skill)
    }

    private func displayZoneName(_ zone: FrontZone) -> String {
        guard !zone.name.isEmpty,
              !zone.name.contains("_"),
              !zone.name.hasPrefix("theater"),
              !zone.name.hasPrefix("front"),
              zone.name != zone.id.rawValue else {
            return "\(displayFactionName(zone.faction))方面"
        }
        return displayGeneralText(zone.name, fallback: "\(displayFactionName(zone.faction))方面")
    }

    private func displayGeneralRank(_ rank: String) -> String {
        let text = displayGeneralText(rank, fallback: "将领")
        return text
            .replacingOccurrences(of: "Field Marshal", with: "行军总管")
            .replacingOccurrences(of: "Army Commander", with: "行军总管")
            .replacingOccurrences(of: "General", with: "将领")
    }

    private func displayFactionName(_ faction: Faction) -> String {
        switch faction {
        case .germany, .allies:
            return "旧剧本势力"
        default:
            return faction.displayName
        }
    }

    private func displayDivisionName(_ division: Division) -> String {
        let trimmed = division.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = "\(displayFactionName(division.faction))\(division.unitKindDisplayName)"
        guard !trimmed.isEmpty else {
            return displayGeneralText(fallback, fallback: "军队")
        }
        return displayGeneralText(trimmed, fallback: fallback)
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
}
