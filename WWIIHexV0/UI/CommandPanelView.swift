import SwiftUI

struct CommandPanelView: View {
    let selectedDivision: Division?
    let activeFaction: Faction
    let phase: GamePhase
    let playerFaction: Faction
    let observerModeEnabled: Bool
    let lastCommandMessage: String?
    let onHold: () -> Void
    let onAllowRetreat: () -> Void
    let onResupply: () -> Void
    let onEndTurn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("军令")
                .font(.headline)

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button(action: onHold) {
                    Label("固守", systemImage: "shield.fill")
                }
                .disabled(!canSetHold)

                Button(action: onAllowRetreat) {
                    Label("准退", systemImage: "arrow.uturn.backward.circle")
                }
                .disabled(!canSetRetreatable)

                Button(action: onResupply) {
                    Label("整军", systemImage: "cross.circle")
                }
                .disabled(!canCommandSelectedUnit)
            }
            .buttonStyle(.bordered)

            Button(action: onEndTurn) {
                Label("结束回合", systemImage: "forward.end")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if let lastCommandMessage {
                Text(displayCommandMessage(lastCommandMessage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .suitangPanel()
    }

    private var canCommandSelectedUnit: Bool {
        guard !observerModeEnabled else {
            return false
        }

        guard let selectedDivision else {
            return false
        }

        return selectedDivision.faction == playerFaction &&
            activeFaction == playerFaction &&
            phase.allowsPlayerInput &&
            !selectedDivision.hasActed
    }

    private var canSetHold: Bool {
        canCommandSelectedUnit && selectedDivision?.retreatMode != .hold
    }

    private var canSetRetreatable: Bool {
        canCommandSelectedUnit && selectedDivision?.retreatMode != .retreatable
    }

    private var statusText: String {
        if observerModeEnabled {
            return "观察模式：军令不可用。"
        }

        guard let selectedDivision else {
            return "未选择可行动军队。"
        }

        guard selectedDivision.faction == playerFaction else {
            return "已选择敌军，不能下令。"
        }

        guard activeFaction == playerFaction, phase.allowsPlayerInput else {
            return "\(phase.displayName) 阶段不能下达军令。"
        }

        guard !selectedDivision.hasActed else {
            return "该军队本回合已行动。"
        }

        return "可移动、攻击、固守或整军。"
    }

    private func displayCommandMessage(_ message: String) -> String {
        sanitizeCommandRawIdentifiers(in: message)
            .replacingOccurrences(of: "rawJSON", with: "军情记录")
            .replacingOccurrences(of: "rawJson", with: "军情记录")
            .replacingOccurrences(of: "raw JSON", with: "军情记录")
            .replacingOccurrences(of: "raw json", with: "军情记录")
            .replacingOccurrences(of: "JSON", with: "军情记录")
            .replacingOccurrences(of: "json", with: "军情记录")
            .replacingOccurrences(of: "Schema", with: "格式")
            .replacingOccurrences(of: "schema", with: "格式")
            .replacingOccurrences(of: "RuleEngine", with: "军令校验")
            .replacingOccurrences(of: "ZoneDirective", with: "方面军令")
            .replacingOccurrences(of: "WarDeploymentState", with: "行军部署")
            .replacingOccurrences(of: "FrontZone", with: "行军防区")
            .replacingOccurrences(of: "Division", with: "军队")
            .replacingOccurrences(of: "Generated no executable commands", with: "未形成可执行军令")
            .replacingOccurrences(of: "No executable commands generated", with: "未形成可执行军令")
            .replacingOccurrences(of: "commands", with: "命令")
            .replacingOccurrences(of: "Command", with: "命令")
            .replacingOccurrences(of: "command", with: "命令")
            .replacingOccurrences(of: "directive", with: "军令")
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
            .replacingOccurrences(of: "MockAI", with: "本地模拟朝堂")
            .replacingOccurrences(of: "AI", with: "军议")
            .replacingOccurrences(of: "Legacy Pipeline", with: "备用军议路径")
            .replacingOccurrences(of: "Legacy pipeline", with: "备用军议路径")
            .replacingOccurrences(of: "legacy pipeline", with: "备用军议路径")
            .replacingOccurrences(of: "Pipeline", with: "军议路径")
            .replacingOccurrences(of: "pipeline", with: "军议路径")
            .replacingOccurrences(of: "Fallback", with: "备用处置")
            .replacingOccurrences(of: "fallback", with: "备用处置")
            .replacingOccurrences(of: "hexToTheater", with: "方面归属")
            .replacingOccurrences(of: "HexTile", with: "地块")
            .replacingOccurrences(of: "Hexes", with: "地块")
            .replacingOccurrences(of: "Hex", with: "地块")
            .replacingOccurrences(of: "hexes", with: "地块")
            .replacingOccurrences(of: "hex", with: "地块")
    }

    private func sanitizeCommandRawIdentifiers(in message: String) -> String {
        message
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
