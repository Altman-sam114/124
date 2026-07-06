import SwiftUI

struct FirstTurnGuideView: View {
    let gameState: GameState
    let onClose: () -> Void

    private let guideSteps: [(title: String, detail: String)] = [
        ("先看大势", "确认当前势力、粮草、胜负目标和东线/西线压力。"),
        ("选中军队", "点击己方军队后查看高亮地块；可进军、攻击、固守、整军或准退。"),
        ("查看州郡", "点击城池、关隘或粮仓州郡，判断粮道、敌军和胜负价值。"),
        ("交给总管", "在军情面板的总管页下达固守或进军，微操过的军队本回合不会被覆盖。"),
        ("结束回合", "玩家军令结束后交给朝堂自动行动，再从战报复盘执行结果。")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("开局引导", systemImage: "scroll")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(SuitangDesignTokens.ink)

                        Text("\(scenarioTitle) · 第 \(gameState.turn) 回合 · \(gameState.activeFaction.displayName) 行动")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("关闭", systemImage: "xmark", action: onClose)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.bordered)
                        .frame(minWidth: SuitangDesignTokens.minimumTapTarget, minHeight: SuitangDesignTokens.minimumTapTarget)
                }

                Text("第一回合建议按以下顺序推进。所有行动仍会按军令规则判定。")
                    .font(.body)
                    .foregroundStyle(SuitangDesignTokens.ink)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(guideSteps.indices, id: \.self) { index in
                        let step = guideSteps[index]

                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.headline)
                                .bold()
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(SuitangDesignTokens.cinnabar, in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(step.title)
                                    .font(.headline)
                                    .foregroundStyle(SuitangDesignTokens.ink)

                                Text(step.detail)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(SuitangDesignTokens.insetBackground, in: RoundedRectangle(cornerRadius: SuitangDesignTokens.cornerRadius))
                    }
                }

                Label("可随时从战报与战局复核查看当前局势，不确定时先固守再结束回合。", systemImage: "exclamationmark.triangle")
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
}
