import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PlatformStyles {
    static var systemBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    static var secondarySystemBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    static var tertiarySystemBackground: Color {
        #if os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color(uiColor: .tertiarySystemBackground)
        #endif
    }

    static var panelStroke: Color {
        .secondary.opacity(0.28)
    }

    static var selectionTint: Color {
        .yellow.opacity(0.18)
    }
}

enum SuitangDesignTokens {
    static let cornerRadius: CGFloat = 8
    static let panelPadding: CGFloat = 12
    static let compactPadding: CGFloat = 8
    static let strokeWidth: CGFloat = 1
    static let minimumTapTarget: CGFloat = 44

    static var silk: Color {
        Color(red: 0.95, green: 0.91, blue: 0.78)
    }

    static var ink: Color {
        Color(red: 0.12, green: 0.14, blue: 0.13)
    }

    static var cinnabar: Color {
        Color(red: 0.58, green: 0.10, blue: 0.09)
    }

    static var copper: Color {
        Color(red: 0.62, green: 0.38, blue: 0.14)
    }

    static var jade: Color {
        Color(red: 0.13, green: 0.43, blue: 0.36)
    }

    static var river: Color {
        Color(red: 0.12, green: 0.42, blue: 0.57)
    }

    static var panelBackground: Color {
        Color(red: 0.98, green: 0.95, blue: 0.86)
    }

    static var elevatedPanelBackground: Color {
        Color(red: 0.93, green: 0.96, blue: 0.91)
    }

    static var insetBackground: Color {
        Color(red: 0.90, green: 0.93, blue: 0.88)
    }

    static var panelStroke: Color {
        copper.opacity(0.55)
    }

    static var accentStroke: Color {
        cinnabar.opacity(0.72)
    }
}

enum SuitangPanelProminence {
    case standard
    case elevated
    case inset
    case chrome
}

private struct SuitangPanelModifier: ViewModifier {
    let prominence: SuitangPanelProminence

    func body(content: Content) -> some View {
        content
            .padding(prominence.padding)
            .background(prominence.background, in: RoundedRectangle(cornerRadius: prominence.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: prominence.cornerRadius)
                    .stroke(prominence.stroke, lineWidth: SuitangDesignTokens.strokeWidth)
            }
            .shadow(
                color: prominence.shadowColor,
                radius: prominence.shadowRadius,
                x: 0,
                y: prominence.shadowYOffset
            )
    }
}

extension View {
    func suitangPanel(_ prominence: SuitangPanelProminence = .standard) -> some View {
        modifier(SuitangPanelModifier(prominence: prominence))
    }
}

private extension SuitangPanelProminence {
    var padding: CGFloat {
        switch self {
        case .standard, .elevated:
            return SuitangDesignTokens.panelPadding
        case .inset, .chrome:
            return SuitangDesignTokens.compactPadding
        }
    }

    var cornerRadius: CGFloat {
        SuitangDesignTokens.cornerRadius
    }

    var background: Color {
        switch self {
        case .standard:
            return SuitangDesignTokens.panelBackground
        case .elevated:
            return SuitangDesignTokens.elevatedPanelBackground
        case .inset:
            return SuitangDesignTokens.insetBackground
        case .chrome:
            return SuitangDesignTokens.panelBackground.opacity(0.92)
        }
    }

    var stroke: Color {
        switch self {
        case .standard, .chrome:
            return SuitangDesignTokens.panelStroke
        case .elevated:
            return SuitangDesignTokens.accentStroke
        case .inset:
            return SuitangDesignTokens.jade.opacity(0.36)
        }
    }

    var shadowColor: Color {
        switch self {
        case .elevated:
            return SuitangDesignTokens.ink.opacity(0.18)
        case .standard, .inset, .chrome:
            return .clear
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .elevated:
            return 10
        case .standard, .inset, .chrome:
            return 0
        }
    }

    var shadowYOffset: CGFloat {
        switch self {
        case .elevated:
            return 4
        case .standard, .inset, .chrome:
            return 0
        }
    }
}
