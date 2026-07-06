import SwiftUI

struct RootGameView: View {
    @ObservedObject var container: AppContainer
    @State private var selectedCompactPanel: CompactInfoPanel = .unit
    @State private var isInfoExpanded = false
    @State private var isGeneralProfilePresented = false
    @State private var isFirstTurnGuidePresented = false
    @State private var isGameSettingsPresented = false
    @State private var isReleaseChecklistPresented = false

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            ZStack(alignment: .bottomTrailing) {
                boardView
                    .ignoresSafeArea()

                VStack {
                    HUDView(
                        gameState: container.gameState,
                        hasSavedGame: container.hasSavedGame,
                        saveStatus: container.saveStatus,
                        onEndTurn: container.advanceOrRunAI,
                        onNewGame: container.startNewGame,
                        onContinueGame: container.continueSavedGame,
                        onResetGame: container.resetGame,
                        onShowGuide: { isFirstTurnGuidePresented = true },
                        onShowSettings: { isGameSettingsPresented = true },
                        onShowChecklist: { isReleaseChecklistPresented = true }
                    )
                    .padding(.top, 8)
                    .padding(.horizontal, 8)

                    Picker("地图图层", selection: Binding(
                        get: { container.mapDisplayLayer },
                        set: { container.setMapDisplayLayer($0) }
                    )) {
                        ForEach(MapDisplayLayer.allCases) { layer in
                            Text(layer.displayName).tag(layer)
                        }
                    }
                    .pickerStyle(.segmented)
                    .suitangPanel(.chrome)
                    .padding(.horizontal, 8)

                    Toggle("观战", isOn: Binding(
                        get: { container.observerModeEnabled },
                        set: { container.setObserverModeEnabled($0) }
                    ))
                    .toggleStyle(.button)
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: SuitangDesignTokens.minimumTapTarget)
                    .suitangPanel(.chrome)
                    .padding(.horizontal, 8)

                    Spacer()
                }

                if isInfoExpanded {
                    infoOverlay(isLandscape: isLandscape, size: proxy.size)
                        .transition(.opacity)
                }

                Button {
                    isInfoExpanded.toggle()
                } label: {
                    Label(isInfoExpanded ? "收起军情" : "军情", systemImage: isInfoExpanded ? "xmark.circle" : "sidebar.left")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: SuitangDesignTokens.minimumTapTarget)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(10)

                UnitTooltipView(division: container.selectedDivision)
                    .allowsHitTesting(false)
            }
        }
        .background(PlatformStyles.systemBackground)
        .sheet(isPresented: $isGeneralProfilePresented) {
            if let general = container.selectedGeneral {
                GeneralProfileView(
                    general: general,
                    assignment: container.selectedGeneralAssignment,
                    zone: container.selectedGeneralCommandZone,
                    assignedDivisions: container.selectedGeneralAssignedDivisions,
                    hqUnderAttack: container.selectedGeneralHQUnderAttack,
                    onClose: { isGeneralProfilePresented = false }
                )
            } else {
                Text("未选择将领。")
                    .font(.headline)
                    .padding()
            }
        }
        .sheet(isPresented: $isFirstTurnGuidePresented) {
            FirstTurnGuideView(
                gameState: container.gameState,
                onClose: { isFirstTurnGuidePresented = false }
            )
        }
        .sheet(isPresented: $isGameSettingsPresented) {
            GameSettingsView(
                mapDisplayLayer: Binding(
                    get: { container.mapDisplayLayer },
                    set: { container.setMapDisplayLayer($0) }
                ),
                observerModeEnabled: Binding(
                    get: { container.observerModeEnabled },
                    set: { container.setObserverModeEnabled($0) }
                ),
                playerFaction: Binding(
                    get: { container.playerFaction },
                    set: { container.setPlayerFaction($0) }
                ),
                playableFactions: container.playableFactions,
                hasSavedGame: container.hasSavedGame,
                saveStatus: container.saveStatus,
                onClose: { isGameSettingsPresented = false }
            )
        }
        .sheet(isPresented: $isReleaseChecklistPresented) {
            ReleaseChecklistView(
                gameState: container.gameState,
                hasSavedGame: container.hasSavedGame,
                saveStatus: container.saveStatus,
                onClose: { isReleaseChecklistPresented = false }
            )
        }
    }

    private var boardView: some View {
        BoardSceneView(
            renderState: BoardSceneAdapter.renderState(from: container),
            onHexTapped: container.handleBoardTap
        )
        .accessibilityLabel("战局地图")
    }

    private func infoOverlay(isLandscape: Bool, size: CGSize) -> some View {
        let width = isLandscape ? min(max(size.width * 0.32, 260), 360) : size.width
        let height = isLandscape ? size.height : min(max(size.height * 0.44, 320), 460)

        return VStack(spacing: 0) {
            compactPanelWithTabs
        }
        .frame(width: width, height: height)
        .background(SuitangDesignTokens.panelBackground.opacity(0.94), in: RoundedRectangle(cornerRadius: SuitangDesignTokens.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: SuitangDesignTokens.cornerRadius)
                .stroke(SuitangDesignTokens.accentStroke, lineWidth: SuitangDesignTokens.strokeWidth)
        }
        .padding(isLandscape ? 10 : 0)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: isLandscape ? .trailing : .bottom
        )
    }

    private var compactPanelWithTabs: some View {
        VStack(spacing: 0) {
            Picker("军情面板", selection: $selectedCompactPanel) {
                ForEach(CompactInfoPanel.allCases) { panel in
                    Text(panel.rawValue).tag(panel)
                }
            }
            .pickerStyle(.segmented)
            .padding(8)

            compactPanel
        }
    }

    @ViewBuilder
    private var compactPanel: some View {
        ScrollView {
            VStack(spacing: 10) {
                switch selectedCompactPanel {
                case .unit:
                    UnitInspectorView(
                        division: container.selectedDivision,
                        playerFaction: container.playerFaction,
                        strategicState: container.selectedUnitInspectorStrategicState
                    )
                    RegionInspectorView(
                        inspectorState: container.selectedRegionInspectorState,
                        canGovernRegion: container.canGovernSelectedRegion,
                        onGovernRegion: container.governSelectedRegion
                    )
                    CommandPanelView(
                        selectedDivision: container.selectedDivision,
                        activeFaction: container.gameState.activeFaction,
                        phase: container.gameState.phase,
                        playerFaction: container.playerFaction,
                        observerModeEnabled: container.observerModeEnabled,
                        lastCommandMessage: container.lastCommandMessage,
                        onHold: container.holdSelected,
                        onAllowRetreat: container.allowRetreatSelected,
                        onResupply: container.resupplySelected,
                        onEndTurn: container.advanceOrRunAI
                    )
                    GeneralCommandPanelView(
                        zone: container.selectedGeneralCommandZone,
                        general: container.selectedGeneral,
                        assignment: container.selectedGeneralAssignment,
                        assignedDivisions: container.selectedGeneralAssignedDivisions,
                        targetRegion: container.selectedGeneralTargetRegion,
                        targetZone: container.selectedGeneralTargetZone,
                        hqUnderAttack: container.selectedGeneralHQUnderAttack,
                        plannedOperations: container.selectedGeneralPlannedOperations,
                        canHoldLine: container.canOrderSelectedGeneralHoldLine,
                        canAttackRegion: container.canOrderSelectedGeneralAttackRegion,
                        onShowProfile: { isGeneralProfilePresented = true },
                        onHoldLine: container.orderSelectedGeneralHoldLine,
                        onAttackRegion: container.orderSelectedGeneralAttackRegion
                    )
                case .region:
                    RegionInspectorView(
                        inspectorState: container.selectedRegionInspectorState,
                        canGovernRegion: container.canGovernSelectedRegion,
                        onGovernRegion: container.governSelectedRegion
                    )
                case .general:
                    GeneralCommandPanelView(
                        zone: container.selectedGeneralCommandZone,
                        general: container.selectedGeneral,
                        assignment: container.selectedGeneralAssignment,
                        assignedDivisions: container.selectedGeneralAssignedDivisions,
                        targetRegion: container.selectedGeneralTargetRegion,
                        targetZone: container.selectedGeneralTargetZone,
                        hqUnderAttack: container.selectedGeneralHQUnderAttack,
                        plannedOperations: container.selectedGeneralPlannedOperations,
                        canHoldLine: container.canOrderSelectedGeneralHoldLine,
                        canAttackRegion: container.canOrderSelectedGeneralAttackRegion,
                        onShowProfile: { isGeneralProfilePresented = true },
                        onHoldLine: container.orderSelectedGeneralHoldLine,
                        onAttackRegion: container.orderSelectedGeneralAttackRegion
                    )
                case .log:
                    EventLogView(
                        entries: container.displayEventLog,
                        agentRecord: container.lastAgentDecisionRecord,
                        directiveRecords: container.lastWarDirectiveRecords,
                        courtRecord: container.gameState.diplomacyState.latestCourtRecord
                    )
                case .economy:
                    EconomyPanelView(
                        gameState: container.gameState,
                        playerFaction: container.playerFaction,
                        observerModeEnabled: container.observerModeEnabled,
                        onQueueProduction: container.queueProduction
                    )
                case .diplomacy:
                    DiplomacyPanelView(
                        diplomacyState: container.gameState.diplomacyState,
                        activeFaction: container.gameState.activeFaction,
                        diplomacyTarget: container.playerDiplomacyTarget,
                        submissionPresenceSummaries: container.submissionPresenceSummaries,
                        canResolveSubmissionHandoff: container.canResolveSubmissionHandoff,
                        canIssueDiplomacy: container.canIssuePlayerDiplomacy,
                        onProposeTruce: container.proposeTruceToDiplomacyTarget,
                        onAcceptSubmission: container.acceptSubmissionFromDiplomacyTarget,
                        onResolveSubmissionHandoff: container.resolveSubmissionHandoff
                    )
                case .agent:
                    AgentPanelView(
                        record: container.lastAgentDecisionRecord,
                        rulerRecord: container.gameState.diplomacyState.latestRulerRecord,
                        courtRecord: container.gameState.diplomacyState.latestCourtRecord,
                        directiveRecords: container.lastWarDirectiveRecords
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
    }
}

private enum CompactInfoPanel: String, CaseIterable, Identifiable {
    case unit = "军队"
    case region = "州郡"
    case general = "总管"
    case log = "战报"
    case economy = "粮饷"
    case diplomacy = "外交"
    case agent = "朝堂"

    var id: String {
        rawValue
    }
}
