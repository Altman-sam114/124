import SwiftUI

struct GameSettingsView: View {
    @Binding var mapDisplayLayer: MapDisplayLayer
    @Binding var observerModeEnabled: Bool
    @Binding var playerFaction: Faction

    let playableFactions: [Faction]
    let hasSavedGame: Bool
    let saveStatus: GameSaveStatus?
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("基础设置", systemImage: "slider.horizontal.3")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(SuitangDesignTokens.ink)

                    Text("本页调整本局执掌势力、界面和观战状态。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("关闭", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .frame(minWidth: SuitangDesignTokens.minimumTapTarget, minHeight: SuitangDesignTokens.minimumTapTarget)
            }

            VStack(alignment: .leading, spacing: 12) {
                Toggle("观战模式", isOn: $observerModeEnabled)
                    .toggleStyle(.switch)
                    .frame(minHeight: SuitangDesignTokens.minimumTapTarget)

                LabeledContent("执掌势力") {
                    Picker("执掌势力", selection: $playerFaction) {
                        ForEach(playableFactions, id: \.self) { faction in
                            Text(faction.displayName).tag(faction)
                        }
                    }
                    .pickerStyle(.menu)
                }

                LabeledContent("地图图层") {
                    Picker("地图图层", selection: $mapDisplayLayer) {
                        ForEach(MapDisplayLayer.allCases) { layer in
                            Text(layer.displayName).tag(layer)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Divider()

                LabeledContent("本地存档", value: hasSavedGame ? "可继续" : "未发现")
                LabeledContent("存档范围", value: "战局状态与执掌势力")
                LabeledContent("存档反馈", value: saveStatus?.title ?? "暂无异常")

                if let saveStatus {
                    SaveStatusBanner(status: saveStatus)
                }
            }
            .font(.body)
            .foregroundStyle(SuitangDesignTokens.ink)
            .padding(12)
            .background(SuitangDesignTokens.insetBackground, in: RoundedRectangle(cornerRadius: SuitangDesignTokens.cornerRadius))

            Label("执掌势力会随本局存档保存；地图图层和观战模式不写入存档。", systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .suitangPanel(.elevated)
        .padding()
        .background(SuitangDesignTokens.silk.opacity(0.45))
    }
}

struct SaveStatusBanner: View {
    let status: GameSaveStatus

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: iconName)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(SuitangDesignTokens.ink)

                if let detail = status.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var iconName: String {
        switch status.severity {
        case .success:
            return "checkmark.circle.fill"
        case .notice:
            return "info.circle.fill"
        case .failure:
            return "xmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch status.severity {
        case .success:
            return SuitangDesignTokens.jade
        case .notice:
            return SuitangDesignTokens.copper
        case .failure:
            return SuitangDesignTokens.cinnabar
        }
    }
}
