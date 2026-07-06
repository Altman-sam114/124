import SwiftUI

struct EventLogView: View {
    let entries: [GameLogEntry]
    let agentRecord: AgentDecisionRecord?
    let directiveRecords: [WarDirectiveRecord]
    let courtRecord: CourtDecisionRecord?

    init(
        entries: [GameLogEntry],
        agentRecord: AgentDecisionRecord? = nil,
        directiveRecords: [WarDirectiveRecord] = [],
        courtRecord: CourtDecisionRecord? = nil
    ) {
        self.entries = entries
        self.agentRecord = agentRecord
        self.directiveRecords = directiveRecords
        self.courtRecord = courtRecord
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("战报")
                .font(.headline)

            reportSummary

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if recentEntries.isEmpty {
                        Text("暂无战报。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentEntries) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.category.displayName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(item.category.foregroundStyle)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(item.category.backgroundStyle)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))

                                    Text(metadata(for: item.entry))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Text(displayedEventMessage(item.entry.message))
                                    .font(.body)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(minHeight: 120)
        }
        .suitangPanel()
    }

    private var reportSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let courtRecord {
                LabeledContent("朝堂") {
                    Text(courtRecord.rulerRecord.posture.displayName)
                }
            }

            if let agentRecord {
                LabeledContent("军议意图") {
                    Text(displayedIntent(agentRecord.parsedIntent))
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                }
            }

            LabeledContent("方面军令") {
                Text("共 \(directiveRecords.count) 条，成功 \(executedDirectiveCommandCount) 条，拒绝 \(rejectedDirectiveCommandCount) 条")
            }

            if !priorityEntries.isEmpty {
                Text("本回合重点")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(priorityEntries) { item in
                    Label(displayedEventMessage(item.entry.message), systemImage: item.category.systemImage)
                        .font(.caption)
                        .foregroundStyle(item.category.foregroundStyle)
                        .lineLimit(2)
                }
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .suitangPanel(.inset)
    }

    private var recentEntries: [LogDisplayEntry] {
        entries
            .suffix(60)
            .reversed()
            .map { LogDisplayEntry(entry: $0, category: LogDisplayCategory(entry: $0)) }
    }

    private var priorityEntries: [LogDisplayEntry] {
        recentEntries
            .filter { $0.category.isBattleReportPriority }
            .prefix(4)
            .map { $0 }
    }

    private var executedDirectiveCommandCount: Int {
        directiveRecords.flatMap(\.commandResults).filter(\.executed).count
    }

    private var rejectedDirectiveCommandCount: Int {
        directiveRecords.flatMap(\.commandResults).filter { !$0.executed }.count
    }

    private func metadata(for entry: GameLogEntry) -> String {
        let faction = entry.faction?.displayName ?? "系统"
        let phase = entry.phase?.displayName ?? "开局"
        let base = "第 \(entry.turn) 回合，\(faction)，\(phase)"
        if entry.relatedRecordId != nil {
            return "\(base)，\(relatedRecordLabel(for: entry))"
        }
        return base
    }

    private func relatedRecordLabel(for entry: GameLogEntry) -> String {
        switch entry.category {
        case .diplomacy:
            return "外交记录"
        case .frontChange, .theaterChange, .regionOwnerChange:
            return "局势记录"
        default:
            return "复盘记录"
        }
    }

    private func displayedIntent(_ intent: String?) -> String {
        guard let intent = intent?.trimmingCharacters(in: .whitespacesAndNewlines),
              !intent.isEmpty else {
            return "无"
        }

        let normalized = intent.lowercased()
        switch normalized {
        case "move":
            return "准备行军"
        case "attack":
            return "准备进军"
        case "hold":
            return "准备固守"
        case "resupply":
            return "准备整补粮草"
        default:
            break
        }

        if normalized.hasPrefix("move") {
            return "准备行军"
        }
        if normalized.hasPrefix("attack") {
            return "准备进军"
        }
        if normalized.hasPrefix("hold") {
            return "准备固守"
        }
        if normalized.hasPrefix("resupply") || normalized.contains("supply") {
            return "准备整补粮草"
        }

        if normalized.range(of: #"\bv[0-9]+(\.[0-9]+)*\b"#, options: .regularExpression) != nil
            || normalized.contains("directive")
            || normalized.contains("json")
            || normalized.contains("agent")
            || normalized.contains("mock")
            || normalized.contains("command")
            || normalized.contains("ruleengine") {
            return "已记录结构化意图"
        }

        if normalized.range(of: #"^[a-z0-9_\-]+$"#, options: .regularExpression) != nil {
            return "已记录军议意图"
        }

        return displayDiagnosticText(intent)
    }

    private func displayedEventMessage(_ message: String) -> String {
        displayDiagnosticText(message)
    }

    private func displayDiagnosticText(_ text: String) -> String {
        sanitizeRawIdentifiers(in: text)
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

private struct LogDisplayEntry: Identifiable {
    let entry: GameLogEntry
    let category: LogDisplayCategory

    var id: UUID {
        entry.id
    }
}

private enum LogDisplayCategory {
    case combat
    case retreat
    case reinforcement
    case encirclement
    case supply
    case frontChange
    case theaterChange
    case regionOwnerChange
    case diplomacy
    case event

    init(entry: GameLogEntry) {
        switch entry.category {
        case .combat:
            self = .combat
            return
        case .retreat:
            self = .retreat
            return
        case .reinforce:
            self = .reinforcement
            return
        case .encircle:
            self = .encirclement
            return
        case .supply:
            self = .supply
            return
        case .frontChange:
            self = .frontChange
            return
        case .theaterChange:
            self = .theaterChange
            return
        case .regionOwnerChange:
            self = .regionOwnerChange
            return
        case .diplomacy:
            self = .diplomacy
            return
        case .event:
            break
        }

        let message = entry.message
        let text = message.lowercased()

        if text.contains("retreat")
            || text.contains("routed")
            || text.contains("routing")
            || message.contains("撤退")
            || message.contains("退却")
            || message.contains("溃退") {
            self = .retreat
        } else if text.contains("reinforce")
            || text.contains("replacement")
            || text.contains("replenish")
            || message.contains("补员")
            || message.contains("整补")
            || message.contains("补充")
            || message.contains("整军") {
            self = .reinforcement
        } else if text.contains("encircle")
            || text.contains("encircled")
            || message.contains("围困")
            || message.contains("包围")
            || message.contains("断粮") {
            self = .encirclement
        } else if text.contains("attack")
            || text.contains("damage")
            || text.contains("combat")
            || text.contains("hit")
            || message.contains("攻击")
            || message.contains("进攻")
            || message.contains("进军")
            || message.contains("战斗")
            || message.contains("打击")
            || message.contains("伤亡")
            || message.contains("损失")
            || message.contains("命中") {
            self = .combat
        } else if text.contains("supply")
            || text.contains("supplied")
            || message.contains("粮道")
            || message.contains("补给")
            || message.contains("粮草")
            || message.contains("军粮") {
            self = .supply
        } else {
            self = .event
        }
    }

    var displayName: String {
        switch self {
        case .combat:
            return "战斗"
        case .retreat:
            return "撤退"
        case .reinforcement:
            return "补员"
        case .encirclement:
            return "围困"
        case .supply:
            return "粮道"
        case .frontChange:
            return "前线"
        case .theaterChange:
            return "方面"
        case .regionOwnerChange:
            return "州郡"
        case .diplomacy:
            return "外交"
        case .event:
            return "事件"
        }
    }

    var systemImage: String {
        switch self {
        case .combat:
            return "burst.fill"
        case .retreat:
            return "arrow.uturn.backward"
        case .reinforcement:
            return "cross.circle"
        case .encirclement:
            return "scope"
        case .supply:
            return "shippingbox"
        case .frontChange:
            return "point.topleft.down.curvedto.point.bottomright.up"
        case .theaterChange:
            return "map"
        case .regionOwnerChange:
            return "flag"
        case .diplomacy:
            return "scroll"
        case .event:
            return "circle"
        }
    }

    var isBattleReportPriority: Bool {
        switch self {
        case .combat, .retreat, .encirclement, .supply, .frontChange, .theaterChange, .regionOwnerChange, .diplomacy:
            return true
        case .reinforcement, .event:
            return false
        }
    }

    var foregroundStyle: Color {
        switch self {
        case .combat:
            return .red
        case .retreat:
            return .orange
        case .reinforcement:
            return .green
        case .encirclement:
            return .purple
        case .supply:
            return .teal
        case .frontChange:
            return .blue
        case .theaterChange:
            return .indigo
        case .regionOwnerChange:
            return .mint
        case .diplomacy:
            return .cyan
        case .event:
            return .secondary
        }
    }

    var backgroundStyle: Color {
        foregroundStyle.opacity(0.12)
    }
}
