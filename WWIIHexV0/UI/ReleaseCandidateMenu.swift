import SwiftUI

struct ReleaseCandidateMenu: View {
    let onShowGuide: () -> Void
    let onShowSettings: () -> Void
    let onShowChecklist: () -> Void

    var body: some View {
        Menu {
            Button("开局引导", systemImage: "scroll", action: onShowGuide)
            Button("基础设置", systemImage: "slider.horizontal.3", action: onShowSettings)
            Button("战局复核", systemImage: "checklist", action: onShowChecklist)
        } label: {
            Label("筹备", systemImage: "wrench.and.screwdriver")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .buttonStyle(.bordered)
        .frame(minHeight: SuitangDesignTokens.minimumTapTarget)
    }
}
