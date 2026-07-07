import SwiftUI

struct RegionInspectorView: View {
    let inspectorState: RegionInspectorState?
    let canGovernRegion: (RegionGovernancePolicy) -> Bool
    let onGovernRegion: (RegionGovernancePolicy) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("州郡")
                .font(.headline)

            if let inspectorState {
                regionDetails(inspectorState)
            } else {
                Text("未选择州郡。")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .suitangPanel()
    }

    private func regionDetails(_ state: RegionInspectorState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayMapName(state.region.name, fallback: "州郡"))
                .font(.subheadline.weight(.semibold))

            Text(regionImportanceSummary(state))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if state.selectedHex != nil {
                LabeledContent("地块") {
                    Text("已选中")
                }

                LabeledContent("地块控制") {
                    Text(state.selectedHexController.map(displayFactionName) ?? "无")
                }

                LabeledContent("当前方面") {
                    Text(displayOptionalMapName(state.selectedHexDynamicTheaterId?.rawValue, fallback: "当前方面"))
                }

                LabeledContent("行军防区") {
                    Text(displayOptionalMapName(state.selectedHexFrontZoneId?.rawValue, fallback: "行军防区"))
                }
            }

            LabeledContent("控制") {
                Text(displayFactionName(state.region.controller))
            }

            LabeledContent("地形") {
                Text(state.region.terrain.displayName)
            }

            LabeledContent("城邑") {
                Text(displayOptionalMapName(state.region.city?.name, fallback: "城邑"))
            }

            LabeledContent("城邑等级") {
                Text(state.cityLevel.displayName)
            }

            LabeledContent("关隘") {
                Text(state.region.terrain == .fortress ? "是" : "否")
            }

            LabeledContent("粮仓") {
                Text("\(state.region.supplyValue)")
            }

            LabeledContent("军械作坊") {
                Text("\(state.region.factories)")
            }

            LabeledContent("产出") {
                Text(state.economicOutput.displaySummary)
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("方面") {
                Text(displayOptionalMapName(state.theaterId?.rawValue, fallback: "当前方面"))
            }

            LabeledContent("防区") {
                Text(displayOptionalMapName(state.frontZoneId?.rawValue, fallback: "行军防区"))
            }

            LabeledContent("边境压力") {
                Text(state.frontPressure, format: .number.precision(.fractionLength(2)))
            }

            LabeledContent("道路仓储") {
                Text("\(state.region.infrastructure)")
            }

            governanceSection(state)

            LabeledContent("要地") {
                Text(objectiveNameSummary(state.objectiveNames))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("要地状态") {
                Text(state.objectiveStatus)
            }

            LabeledContent("己方军队") {
                Text(unitNames(state.friendlyDivisions))
                    .multilineTextAlignment(.trailing)
            }

            LabeledContent("可见敌军") {
                Text(unitNames(state.visibleEnemyDivisions))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func governanceSection(_ state: RegionInspectorState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("太守")
                .font(.subheadline.weight(.semibold))

            ForEach(RegionGovernancePolicy.allCases) { policy in
                VStack(alignment: .leading, spacing: 4) {
                    Button(policy.displayName, systemImage: governanceIcon(for: policy)) {
                        onGovernRegion(policy)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canGovernRegion(policy))
                    .frame(minHeight: SuitangDesignTokens.minimumTapTarget)

                    Text("\(policy.effectSummary(for: state.region))，耗费 \(policy.cost.displaySummary)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("州郡经营会按军令判定消耗府库并更新州郡。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func unitNames(_ divisions: [Division]) -> String {
        guard !divisions.isEmpty else {
            return "无"
        }
        return divisions.map(displayDivisionName).joined(separator: "、")
    }

    private func objectiveNameSummary(_ names: [String]) -> String {
        guard !names.isEmpty else {
            return "无"
        }
        return names
            .map { displayMapName($0, fallback: "要地") }
            .joined(separator: "、")
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
                of: #"\b(germany|france|allied|axis)_[A-Za-z0-9_\-]+\b"#,
                with: "相关旧战局",
                options: .regularExpression
            )
    }

    private func displayDivisionName(_ division: Division) -> String {
        let trimmed = division.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "\(displayFactionName(division.faction))\(division.unitKindDisplayName)"
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

        return sanitized.isEmpty ? "\(displayFactionName(division.faction))\(division.unitKindDisplayName)" : sanitized
    }

    private func sanitizeRawUnitIdentifier(in name: String) -> String {
        name.replacingOccurrences(
            of: #"\b(division|unit)_[A-Za-z0-9_\-]+\b"#,
            with: "相关军队",
            options: .regularExpression
        )
    }

    private func regionImportanceSummary(_ state: RegionInspectorState) -> String {
        var notes: [String] = []
        if state.region.supplyValue >= 3 {
            notes.append("粮仓要地")
        }
        if state.region.factories > 0 || !state.economicOutput.isEmpty {
            notes.append("可供征发")
        }
        if state.frontPressure >= 1 {
            notes.append("边境承压")
        }
        if !state.visibleEnemyDivisions.isEmpty {
            notes.append("敌军可见")
        }
        if !state.objectiveNames.isEmpty {
            notes.append("胜负要点")
        }
        return notes.isEmpty ? "后方州郡，当前无紧急军情。" : notes.joined(separator: "、")
    }

    private func governanceIcon(for policy: RegionGovernancePolicy) -> String {
        switch policy {
        case .repairRoads:
            return "road.lanes"
        case .organizeTuntian:
            return "leaf.fill"
        case .pacifyPopulation:
            return "person.2.fill"
        }
    }
}
