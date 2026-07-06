import SwiftUI

struct UnitTooltipView: View {
    let division: Division?

    var body: some View {
        if let division {
            let divisionDisplayName = displayDivisionName(division)
            VStack(alignment: .leading, spacing: 6) {
                Text(divisionDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                    GridRow {
                        label("兵种")
                        value(division.tooltipTypeCode)
                    }
                    GridRow {
                        label("兵力")
                        value("兵力 \(division.strength)，上限 \(division.maxStrength)")
                    }
                    GridRow {
                        label("粮道")
                        value(division.supplyState.shortDisplayName)
                    }
                    GridRow {
                        label("退守")
                        value(division.retreatMode.tooltipDisplayName)
                    }
                    GridRow {
                        label("行动")
                        value(division.hasActed ? "已" : "待")
                    }
                }
            }
            .padding(10)
            .frame(width: 220, alignment: .leading)
            .background(SuitangDesignTokens.panelBackground.opacity(0.94), in: RoundedRectangle(cornerRadius: SuitangDesignTokens.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: SuitangDesignTokens.cornerRadius)
                    .stroke(SuitangDesignTokens.panelStroke, lineWidth: SuitangDesignTokens.strokeWidth)
            }
            .padding(10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(divisionDisplayName)，\(division.tooltipTypeCode)，兵力 \(division.strength)，上限 \(division.maxStrength)")
        }
    }

    private func displayDivisionName(_ division: Division) -> String {
        displayUnitName(division.name, fallbackKind: division.unitKindDisplayName, faction: division.faction)
    }

    private func displayUnitName(_ name: String, fallbackKind: String, faction: Faction) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "\(faction.displayName)\(fallbackKind)"
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
            .replacingOccurrences(of: "Ardennes", with: "旧战局")
            .replacingOccurrences(of: "Bastogne", with: "旧战局要地")
            .replacingOccurrences(of: "St. Vith", with: "旧战局要地")

        return sanitized.isEmpty ? "\(faction.displayName)\(fallbackKind)" : sanitized
    }

    private func sanitizeRawUnitIdentifier(in name: String) -> String {
        name.replacingOccurrences(
            of: #"\b(division|unit)_[A-Za-z0-9_\-]+\b"#,
            with: "相关军队",
            options: .regularExpression
        )
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

private extension Division {
    var tooltipTypeCode: String {
        unitKindDisplayName
    }
}

private extension RetreatMode {
    var tooltipDisplayName: String {
        switch self {
        case .retreatable:
            return "可退"
        case .hold:
            return "固守"
        }
    }
}
