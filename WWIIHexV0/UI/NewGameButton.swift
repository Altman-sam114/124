import SwiftUI

struct NewGameButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("新局", systemImage: "arrow.counterclockwise")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .buttonStyle(.bordered)
        .frame(minHeight: SuitangDesignTokens.minimumTapTarget)
    }
}

struct GameLifecycleMenu: View {
    let hasSavedGame: Bool
    let onNewGame: (() -> Void)?
    let onContinueGame: (() -> Void)?
    let onResetGame: (() -> Void)?

    var body: some View {
        Menu {
            if let onNewGame {
                Button(action: onNewGame) {
                    Label("新局", systemImage: "plus.circle")
                }
            }
            if let onContinueGame {
                Button(action: onContinueGame) {
                    Label("继续", systemImage: "play.circle")
                }
                    .disabled(!hasSavedGame)
            }
            if let onResetGame {
                Button(role: .destructive, action: onResetGame) {
                    Label("重置", systemImage: "trash")
                }
            }
        } label: {
            Label("局势", systemImage: "tray.full")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .buttonStyle(.bordered)
        .frame(minHeight: SuitangDesignTokens.minimumTapTarget)
    }
}
