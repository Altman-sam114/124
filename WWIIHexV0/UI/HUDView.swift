import SwiftUI

struct HUDView: View {
    let gameState: GameState
    let hasSavedGame: Bool
    let saveStatus: GameSaveStatus?
    let onEndTurn: () -> Void
    let onNewGame: (() -> Void)?
    let onContinueGame: (() -> Void)?
    let onResetGame: (() -> Void)?
    let onShowGuide: (() -> Void)?
    let onShowSettings: (() -> Void)?
    let onShowChecklist: (() -> Void)?

    init(
        gameState: GameState,
        hasSavedGame: Bool = false,
        saveStatus: GameSaveStatus? = nil,
        onEndTurn: @escaping () -> Void,
        onNewGame: (() -> Void)? = nil,
        onContinueGame: (() -> Void)? = nil,
        onResetGame: (() -> Void)? = nil,
        onShowGuide: (() -> Void)? = nil,
        onShowSettings: (() -> Void)? = nil,
        onShowChecklist: (() -> Void)? = nil
    ) {
        self.gameState = gameState
        self.hasSavedGame = hasSavedGame
        self.saveStatus = saveStatus
        self.onEndTurn = onEndTurn
        self.onNewGame = onNewGame
        self.onContinueGame = onContinueGame
        self.onResetGame = onResetGame
        self.onShowGuide = onShowGuide
        self.onShowSettings = onShowSettings
        self.onShowChecklist = onShowChecklist
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(scenarioTitle, systemImage: "flag.fill")
                    .font(.headline)
                    .foregroundStyle(SuitangDesignTokens.ink)

                Spacer()

                if onNewGame != nil || onContinueGame != nil || onResetGame != nil {
                    GameLifecycleMenu(
                        hasSavedGame: hasSavedGame,
                        onNewGame: onNewGame,
                        onContinueGame: onContinueGame,
                        onResetGame: onResetGame
                    )
                }

                if let onShowGuide,
                   let onShowSettings,
                   let onShowChecklist {
                    ReleaseCandidateMenu(
                        onShowGuide: onShowGuide,
                        onShowSettings: onShowSettings,
                        onShowChecklist: onShowChecklist
                    )
                }

                Button(action: onEndTurn) {
                    Label("结束回合", systemImage: "forward.end")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .buttonStyle(.borderedProminent)
                .frame(minHeight: SuitangDesignTokens.minimumTapTarget)
            }

            if let saveStatus, saveStatus.needsAttention {
                SaveStatusBanner(status: saveStatus)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    metric("回合", "第 \(gameState.turn) 回合，共 \(gameState.maxTurns) 回合")
                    metric("执掌", gameState.playerFaction.displayName)
                }

                GridRow {
                    metric("行动", gameState.activeFaction.displayName)
                    metric("阶段", gameState.phase.displayName)
                }

                GridRow {
                    metric("胜负", victoryText)
                    metric("丁口", "\(activeLedger.stockpile.manpower)")
                }

                GridRow {
                    metric("军械", "\(activeLedger.stockpile.industry)")
                    metric("粮草", "\(activeLedger.stockpile.supplies)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .suitangPanel(.elevated)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(SuitangDesignTokens.jade)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SuitangDesignTokens.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var victoryText: String {
        guard let winner = gameState.victoryState.winner else {
            return "未定"
        }
        if let reason = gameState.victoryState.reason {
            return "\(winner.displayName)胜：\(reason.displayName)"
        }
        return "\(winner.displayName)胜"
    }

    private var scenarioTitle: String {
        switch gameState.scenarioId {
        case "wude_618_guanzhong_luoyang":
            return "武德元年"
        case "mapeditor_suitang_scenario":
            return "自定战局"
        case "ardennes_v0", "mapeditor_scenario":
            return "当前战局"
        default:
            return "当前战局"
        }
    }

    private var activeLedger: FactionEconomyLedger {
        gameState.economyState.ledger(for: gameState.playerFaction)
    }
}
