#if os(macOS)
import SwiftUI

@main
struct WWIIHexV0MacApp: App {
    @StateObject private var container = AppContainer.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootGameView(container: container)
                .frame(minWidth: 1200, minHeight: 760)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandMenu("局势") {
                Button("结束回合", action: container.advanceOrRunAI)
                    .keyboardShortcut(.return, modifiers: [.command])

                Button("新局", action: container.startNewGame)
                    .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("继续", action: container.continueSavedGame)
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .disabled(!container.hasSavedGame)

                Button("重置", action: container.resetGame)
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
#endif
