import SpriteKit

enum TerrainStyle {
    static func fillColor(for terrain: BaseTerrain) -> SKColor {
        switch terrain {
        case .plain:
            return SKColor(red: 0.63, green: 0.76, blue: 0.53, alpha: 1)
        case .forest:
            return SKColor(red: 0.22, green: 0.46, blue: 0.28, alpha: 1)
        case .mountain:
            return SKColor(red: 0.55, green: 0.52, blue: 0.46, alpha: 1)
        case .hill:
            return SKColor(red: 0.61, green: 0.66, blue: 0.42, alpha: 1)
        case .city:
            return SKColor(red: 0.74, green: 0.76, blue: 0.73, alpha: 1)
        case .fortress:
            return SKColor(red: 0.43, green: 0.45, blue: 0.47, alpha: 1)
        }
    }

    static func strokeColor(for terrain: BaseTerrain) -> SKColor {
        switch terrain {
        case .fortress:
            return SKColor(red: 0.16, green: 0.17, blue: 0.18, alpha: 1)
        case .city:
            return SKColor(red: 0.39, green: 0.41, blue: 0.40, alpha: 1)
        default:
            return SKColor(red: 0.33, green: 0.38, blue: 0.31, alpha: 1)
        }
    }

    static func textColor(for terrain: BaseTerrain) -> SKColor {
        switch terrain {
        case .forest, .fortress:
            return SKColor(white: 0.96, alpha: 1)
        default:
            return SKColor(white: 0.12, alpha: 1)
        }
    }

    static func unitFillColor(for faction: Faction) -> SKColor {
        switch faction {
        case .germany:
            return SKColor(red: 0.23, green: 0.24, blue: 0.25, alpha: 1)
        case .allies:
            return SKColor(red: 0.12, green: 0.36, blue: 0.68, alpha: 1)
        case .tang:
            return SKColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1)
        case .luoyangSui:
            return SKColor(red: 0.42, green: 0.20, blue: 0.56, alpha: 1)
        case .wagang:
            return SKColor(red: 0.14, green: 0.45, blue: 0.28, alpha: 1)
        case .xia:
            return SKColor(red: 0.10, green: 0.42, blue: 0.48, alpha: 1)
        case .qinXue:
            return SKColor(red: 0.60, green: 0.32, blue: 0.12, alpha: 1)
        case .liuWuzhou:
            return SKColor(red: 0.70, green: 0.42, blue: 0.10, alpha: 1)
        case .tujue:
            return SKColor(red: 0.34, green: 0.38, blue: 0.38, alpha: 1)
        }
    }

    static func unitStrokeColor(for faction: Faction) -> SKColor {
        switch faction {
        case .germany:
            return SKColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1)
        case .allies:
            return SKColor(red: 0.04, green: 0.18, blue: 0.36, alpha: 1)
        case .tang:
            return SKColor(red: 0.26, green: 0.04, blue: 0.04, alpha: 1)
        case .luoyangSui:
            return SKColor(red: 0.20, green: 0.08, blue: 0.30, alpha: 1)
        case .wagang:
            return SKColor(red: 0.04, green: 0.22, blue: 0.12, alpha: 1)
        case .xia:
            return SKColor(red: 0.03, green: 0.20, blue: 0.24, alpha: 1)
        case .qinXue:
            return SKColor(red: 0.28, green: 0.13, blue: 0.04, alpha: 1)
        case .liuWuzhou:
            return SKColor(red: 0.36, green: 0.18, blue: 0.04, alpha: 1)
        case .tujue:
            return SKColor(red: 0.14, green: 0.16, blue: 0.16, alpha: 1)
        }
    }

    static func deploymentUnitColor(for faction: Faction, role: UnitDeploymentRole) -> SKColor {
        switch (faction, role) {
        case (.germany, .frontUnit):
            return SKColor(red: 0.95, green: 0.22, blue: 0.16, alpha: 1)
        case (.germany, .depthUnit):
            return SKColor(red: 0.93, green: 0.58, blue: 0.16, alpha: 1)
        case (.germany, .garrisonUnit):
            return SKColor(red: 0.50, green: 0.50, blue: 0.52, alpha: 1)
        case (.allies, .frontUnit):
            return SKColor(red: 0.15, green: 0.72, blue: 0.98, alpha: 1)
        case (.allies, .depthUnit):
            return SKColor(red: 0.20, green: 0.85, blue: 0.45, alpha: 1)
        case (.allies, .garrisonUnit):
            return SKColor(red: 0.42, green: 0.38, blue: 0.95, alpha: 1)
        case (_, .frontUnit):
            return unitFillColor(for: faction)
        case (_, .depthUnit):
            return unitFillColor(for: faction).withAlphaComponent(0.78)
        case (_, .garrisonUnit):
            return unitStrokeColor(for: faction).withAlphaComponent(0.85)
        }
    }

    static func controllerColor(for faction: Faction?) -> SKColor {
        switch faction {
        case .germany:
            return SKColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
        case .allies:
            return SKColor(red: 0.04, green: 0.20, blue: 0.62, alpha: 1)
        case .tang:
            return SKColor(red: 0.62, green: 0.12, blue: 0.10, alpha: 1)
        case .luoyangSui:
            return SKColor(red: 0.44, green: 0.18, blue: 0.58, alpha: 1)
        case .wagang:
            return SKColor(red: 0.12, green: 0.45, blue: 0.25, alpha: 1)
        case .xia:
            return SKColor(red: 0.08, green: 0.42, blue: 0.48, alpha: 1)
        case .qinXue:
            return SKColor(red: 0.64, green: 0.30, blue: 0.10, alpha: 1)
        case .liuWuzhou:
            return SKColor(red: 0.72, green: 0.40, blue: 0.10, alpha: 1)
        case .tujue:
            return SKColor(red: 0.32, green: 0.36, blue: 0.36, alpha: 1)
        case nil:
            return SKColor(red: 0.88, green: 0.82, blue: 0.45, alpha: 1)
        }
    }

    static func supplyColor(for supplyState: SupplyState) -> SKColor {
        switch supplyState {
        case .supplied:
            return SKColor(red: 0.18, green: 0.72, blue: 0.35, alpha: 1)
        case .lowSupply:
            return SKColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1)
        case .encircled:
            return SKColor(red: 0.86, green: 0.16, blue: 0.12, alpha: 1)
        }
    }

    static let selectedStroke = SKColor(red: 1.0, green: 0.88, blue: 0.18, alpha: 1)
    static let movementFill = SKColor(red: 0.12, green: 0.54, blue: 0.95, alpha: 0.32)
    static let attackFill = SKColor(red: 0.92, green: 0.14, blue: 0.12, alpha: 0.34)
    static let roadStroke = SKColor(red: 0.80, green: 0.73, blue: 0.56, alpha: 1)
    static let riverStroke = SKColor(red: 0.18, green: 0.60, blue: 0.95, alpha: 1)
}
