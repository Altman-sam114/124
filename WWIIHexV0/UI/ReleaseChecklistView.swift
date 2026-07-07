import SwiftUI

struct ReleaseChecklistView: View {
    let gameState: GameState
    let hasSavedGame: Bool
    let saveStatus: GameSaveStatus?
    let onClose: () -> Void

    private let codeReadyItems = [
        "新局优先进入武德元年隋唐剧本",
        "新局、继续、重置和本地自动存档可使用",
        "本局执掌势力可在基础设置中选择并随存档保存",
        "本地存档读取、保存和删除反馈可查看",
        "长安、洛阳、洛口仓、潼关胜负条件已生效",
        "玩家军令、州郡、外交、战报和朝堂记录已有中文闭环",
        "渡口、港口、军议箭头和接触墨线已有最小地图显示",
        "外交议和和纳降已进入统一战局判定",
        "州郡修道、屯田、安民已进入统一战局判定",
        "太守会在自动回合最多执行一条州郡经营命令",
        "使者会在保守条件下执行停战或归附关系命令",
        "归附、停战会生成外交事件记录并关联战报回放",
        "已归附且无实体存在的势力会退出通用回合轮转",
        "外交面板会盘点归附势力残余军队和受控可通行地块",
        "归附接收方可按战局判定接管残余军队和受控地块",
        "归附交接结果会写入外交战报",
        "接收方会在自动回合最多执行一条归附实体交接命令",
        "归附交接后会提示后续治理重点",
        "非玩家势力太守会优先治理高压或需安抚的善后州郡",
        "善后压力州郡被治理后会更新善后进度",
        "善后面板会显示本次处置进度摘要",
        "非玩家势力太守会优先处理尚未处置的善后州郡",
        "善后面板会显示待处置数量和完成状态",
        "无合适治理行动时会说明原因",
        "使者和归附交接暂不行动时会说明原因",
        "可查看当前局势快照、战局说明和地图标识",
        "可区分当前可用内容和待继续观察内容"
    ]

    private let runtimeGateItems = [
        "完整战局体验仍待继续观察",
        "多回合观战仍待继续观察",
        "存档、自动回合、外交交接和善后界面仍需继续观察",
        "当前局势快照只展示本局信息，不代表后续走向已经明确",
        "地图叠加层和正式资产仍待后续打磨"
    ]

    private let futureFeatureItems = [
        "归附交接后的忠诚、叛乱、安置和更完整多回合善后系统",
        "更完整的朝堂决策、水战、围城进度和完整天命与民心效果"
    ]

    private let releaseNotes = [
        "战局定位：武德元年关中河洛争衡，新局进入武德元年剧本",
        "当前入口：新局、继续、重置、军令、外交、自动回合、战报和胜负提示",
        "当前说明：本页展示本局已有内容和仍需留意的战场变化"
    ]

    private let assetBoundaries = [
        "当前城池、关隘、粮仓、渡口、港口和接触态势标识均为临时绘制或根据局势生成",
        "不引入版权不明外部素材；后续画面稳定后再替换正式资产",
        "水路标识、军议箭头和接触墨线仅作地图提示，不改变移动、补给或战斗判定"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("战局复核", systemImage: "checklist")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(SuitangDesignTokens.ink)

                        Text("天命开唐 · 当前战局")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("关闭", systemImage: "xmark", action: onClose)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .frame(minWidth: SuitangDesignTokens.minimumTapTarget, minHeight: SuitangDesignTokens.minimumTapTarget)
                }

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("当前剧本", value: scenarioTitle)
                    LabeledContent("执掌势力", value: gameState.playerFaction.displayName)
                    LabeledContent("当前势力", value: gameState.activeFaction.displayName)
                    LabeledContent("本地存档", value: hasSavedGame ? "可继续" : "未发现")
                    LabeledContent("存档反馈", value: saveStatus?.title ?? "暂无异常")
                    LabeledContent("战局内容", value: "可查看")
                    LabeledContent("当前阶段", value: "继续观察")

                    if let saveStatus {
                        SaveStatusBanner(status: saveStatus)
                    }
                }
                .font(.body)
                .foregroundStyle(SuitangDesignTokens.ink)
                .padding(12)
                .background(SuitangDesignTokens.insetBackground, in: RoundedRectangle(cornerRadius: SuitangDesignTokens.cornerRadius))

                VStack(alignment: .leading, spacing: 8) {
                    Text("当前局势快照")
                        .font(.headline)
                        .foregroundStyle(SuitangDesignTokens.cinnabar)

                    ForEach(staticGateSnapshotRows.indices, id: \.self) { index in
                        let row = staticGateSnapshotRows[index]
                        LabeledContent(row.label, value: row.value)
                            .font(.body)
                            .foregroundStyle(SuitangDesignTokens.ink)
                    }

                    Label("本区块只读取当前局势，不推进回合、不执行新军令。", systemImage: "lock.shield")
                        .font(.callout)
                        .foregroundStyle(SuitangDesignTokens.copper)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(SuitangDesignTokens.insetBackground, in: RoundedRectangle(cornerRadius: SuitangDesignTokens.cornerRadius))

                VStack(alignment: .leading, spacing: 8) {
                    Text("战局说明")
                        .font(.headline)
                        .foregroundStyle(SuitangDesignTokens.cinnabar)

                    ForEach(releaseNotes, id: \.self) { item in
                        Label(item, systemImage: "scroll")
                            .font(.body)
                            .foregroundStyle(SuitangDesignTokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("地图标识")
                        .font(.headline)
                        .foregroundStyle(SuitangDesignTokens.copper)

                    ForEach(assetBoundaries, id: \.self) { item in
                        Label(item, systemImage: "paintpalette")
                            .font(.body)
                            .foregroundStyle(SuitangDesignTokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("当前可用")
                        .font(.headline)
                        .foregroundStyle(SuitangDesignTokens.jade)

                    ForEach(codeReadyItems, id: \.self) { item in
                        Label(item, systemImage: "checkmark.seal")
                            .font(.body)
                            .foregroundStyle(SuitangDesignTokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("待继续观察")
                        .font(.headline)
                        .foregroundStyle(SuitangDesignTokens.copper)

                    ForEach(runtimeGateItems, id: \.self) { item in
                        Label(item, systemImage: "clock.badge.exclamationmark")
                            .font(.body)
                            .foregroundStyle(SuitangDesignTokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("后续功能")
                        .font(.headline)
                        .foregroundStyle(SuitangDesignTokens.river)

                    ForEach(futureFeatureItems, id: \.self) { item in
                        Label(item, systemImage: "arrow.triangle.2.circlepath")
                            .font(.body)
                            .foregroundStyle(SuitangDesignTokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Label("当前面板只展示局势信息；完整体验仍需后续继续打磨。", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(SuitangDesignTokens.copper)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .suitangPanel(.elevated)
            .padding()
        }
        .background(SuitangDesignTokens.silk.opacity(0.45))
    }

    private var scenarioTitle: String {
        switch gameState.scenarioId {
        case "wude_618_guanzhong_luoyang":
            return "武德元年：关中河洛争衡"
        case "mapeditor_suitang_scenario":
            return "自定战局"
        case "ardennes_v0", "mapeditor_scenario":
            return "当前战局"
        default:
            return "当前战局"
        }
    }

    private var staticGateSnapshotRows: [(label: String, value: String)] {
        [
            ("局势判断", "当前快照：可继续观察"),
            ("剧本", scenarioTitle),
            ("执掌势力", gameState.playerFaction.displayName),
            ("回合阶段", "第 \(gameState.turn) 回合，共 \(gameState.maxTurns) 回合 · \(gameState.phase.displayName)"),
            ("行动势力", gameState.activeFaction.displayName),
            ("胜负状态", victorySnapshotTitle),
            ("地图数据", "\(gameState.map.tiles.count) 地块 · \(gameState.map.regions.count) 州郡 · \(gameState.map.regionEdges.count) 邻接"),
            ("地点数据", "\(gameState.map.objectives.count) 目标 · \(gameState.map.featureMarkers.count) 地点 · \(gameState.map.supplySources.count) 补给源"),
            ("军队与接触态势", "\(gameState.divisions.count) 军队 · \(gameState.frontLineState.frontLines.count) 接触处"),
            ("方面与防区", "\(gameState.theaterState.theaters.count) 方面 · \(gameState.warDeploymentState.frontZones.count) 防区"),
            ("外交档案", "\(gameState.diplomacyState.countries.count) 国家 · \(gameState.diplomacyState.relations.count) 关系"),
            ("军情记录", "\(gameState.warDirectiveRecords.count) 军令 · \(gameState.diplomacyState.courtRecords.count) 朝堂 · \(gameState.diplomacyState.diplomacyEventRecords.count) 外交"),
            ("善后记录", "\(gameState.diplomacyState.submissionHandoffRecords.count) 交接 · \(gameState.diplomacyState.submissionAftermathRecords.count) 压力 · \(gameState.diplomacyState.submissionAftermathGovernanceRecords.count) 处置"),
            ("战报记录", "\(gameState.eventLog.count) 条"),
            ("存档状态", hasSavedGame ? "发现本地存档" : "未发现本地存档"),
            ("存档反馈", saveStatus?.summary ?? "暂无异常")
        ]
    }

    private var victorySnapshotTitle: String {
        guard let winner = gameState.victoryState.winner else {
            return "进行中"
        }
        if let reason = gameState.victoryState.reason {
            return "\(winner.displayName) · \(reason.displayName)"
        }
        return "\(winner.displayName) 胜"
    }
}
