import SwiftUI

struct UnitInspectorView: View {
    let division: Division?
    let playerFaction: Faction
    let strategicState: UnitInspectorStrategicState?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("军队详情")
                .font(.headline)

            if let division {
                unitDetails(division)
            } else {
                Text("未选择军队。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .suitangPanel()
    }

    private func unitDetails(_ division: Division) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayDivisionName(division))
                .font(.subheadline.weight(.semibold))

            LabeledContent("势力") {
                Text(displayFactionName(division.faction))
            }

            LabeledContent("操控") {
                Text(division.faction == playerFaction ? "可下令" : "不可下令")
            }

            if let strategicState {
                LabeledContent("地块") {
                    Text(strategicState.regionId == nil ? "未编入州郡" : "州郡内地块")
                }

                LabeledContent("州郡") {
                    Text(displayOptionalMapName(strategicState.regionId?.rawValue, fallback: "州郡"))
                }

                LabeledContent("当前方面") {
                    Text(displayOptionalMapName(strategicState.dynamicTheaterId?.rawValue, fallback: "当前方面"))
                }

                LabeledContent("行军防区") {
                    Text(displayOptionalMapName(strategicState.frontZoneId?.rawValue, fallback: "行军防区"))
                }

                LabeledContent("部署") {
                    Text(strategicState.deploymentRole.displayName)
                }

                LabeledContent("接敌") {
                    Text(frontLineSummary(strategicState.frontLineIds))
                        .multilineTextAlignment(.trailing)
                }
            }

            LabeledContent("兵力") {
                Text(division.inspectorStrengthText)
            }

            LabeledContent("退守") {
                Text(division.retreatMode.displayName)
            }

            LabeledContent("粮道") {
                Text(division.supplyState.displayName)
            }

            LabeledContent("已行动") {
                Text(division.hasActed ? "是" : "否")
            }

            LabeledContent("状态") {
                Text(division.inspectorStatusText)
            }

            LabeledContent("兵种") {
                Text(componentSummary(for: division))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func componentSummary(for division: Division) -> String {
        division.components
            .map { "\($0.type.displayName) \(Int(($0.weight * 100).rounded()))%" }
            .joined(separator: "、")
    }

    private func displayDivisionName(_ division: Division) -> String {
        displayUnitName(division.name, fallbackKind: division.unitKindDisplayName, faction: division.faction)
    }

    private func displayOptionalMapName(_ name: String?, fallback: String) -> String {
        guard let name else {
            return "无"
        }
        return displayMapName(name, fallback: fallback)
    }

    private func displayFactionName(_ faction: Faction) -> String {
        switch faction {
        case .germany, .allies:
            return "旧剧本势力"
        default:
            return faction.displayName
        }
    }

    private func displayMapName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return fallback
        }

        let sanitized = sanitizeRawMapIdentifier(in: trimmed)
            .replacingOccurrences(of: "巴斯托涅", with: "旧战局要地")
            .replacingOccurrences(of: "圣维特", with: "旧战局要地")
            .replacingOccurrences(of: "色当", with: "旧战局要地")
            .replacingOccurrences(of: "阿登", with: "旧战局")
            .replacingOccurrences(of: "Ardennes", with: "旧战局")
            .replacingOccurrences(of: "ardennes", with: "旧战局")
            .replacingOccurrences(of: "Bastogne", with: "旧战局要地")
            .replacingOccurrences(of: "bastogne", with: "旧战局要地")
            .replacingOccurrences(of: "St. Vith", with: "旧战局要地")
            .replacingOccurrences(of: "St Vith", with: "旧战局要地")
            .replacingOccurrences(of: "st. vith", with: "旧战局要地")
            .replacingOccurrences(of: "st vith", with: "旧战局要地")
            .replacingOccurrences(of: "Sedan", with: "旧战局要地")
            .replacingOccurrences(of: "sedan", with: "旧战局要地")
            .replacingOccurrences(of: "德军", with: "旧剧本")
            .replacingOccurrences(of: "盟军", with: "旧剧本")
            .replacingOccurrences(of: "防区", with: "行军防区")

        return sanitized.isEmpty ? fallback : sanitized
    }

    private func sanitizeRawMapIdentifier(in name: String) -> String {
        name
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
                of: #"\bhex_[A-Za-z0-9_\-]+\b"#,
                with: "相关地块",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\b(germany|france|allied|axis)_[A-Za-z0-9_\-]+\b"#,
                with: "相关旧战局",
                options: .regularExpression
            )
    }

    private func displayUnitName(_ name: String, fallbackKind: String, faction: Faction) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "\(displayFactionName(faction))\(fallbackKind)"
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

        return sanitized.isEmpty ? "\(displayFactionName(faction))\(fallbackKind)" : sanitized
    }

    private func sanitizeRawUnitIdentifier(in name: String) -> String {
        name.replacingOccurrences(
            of: #"\b(division|unit)_[A-Za-z0-9_\-]+\b"#,
            with: "相关军队",
            options: .regularExpression
        )
    }

    private func frontLineSummary(_ ids: [FrontLineId]) -> String {
        ids.isEmpty ? "无" : "\(ids.count) 处接触"
    }
}

private extension Division {
    var inspectorStrengthText: String {
        "兵力 \(strength)，上限 \(maxStrength)"
    }

    var inspectorStatusText: String {
        var statuses: [String] = []

        if isRetreating {
            statuses.append("退却中")
        }

        if isDestroyed {
            statuses.append("溃散")
        }

        return statuses.isEmpty ? "待命" : statuses.joined(separator: "、")
    }
}

private extension RetreatMode {
    var displayName: String {
        switch self {
        case .retreatable:
            return "可退"
        case .hold:
            return "固守"
        }
    }
}

private extension UnitDeploymentRole {
    var displayName: String {
        switch self {
        case .frontUnit:
            return "先阵"
        case .depthUnit:
            return "纵深"
        case .garrisonUnit:
            return "驻守"
        }
    }
}

private extension Set where Element == HexDirection {
    var displaySummary: String {
        HexDirection.ordered
            .filter { contains($0) }
            .map(\.displayName)
            .joined(separator: "、")
    }
}
