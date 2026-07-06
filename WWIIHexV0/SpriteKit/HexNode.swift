import SpriteKit

final class HexNode: SKNode {
    let coord: HexCoord

    init(
        displayState: HexDisplayState,
        layout: HexLayout,
        supplySourceFaction: Faction?,
        featureMarkers: [MapFeatureMarker] = [],
        isSelected: Bool,
        isMoveHighlighted: Bool,
        isAttackHighlighted: Bool
    ) {
        self.coord = displayState.coord
        super.init()

        position = layout.hexToPixel(displayState.coord)
        zPosition = 0

        let path = Self.hexPath(layout: layout)
        let base = SKShapeNode(path: path)
        base.fillColor = TerrainStyle.fillColor(for: displayState.terrain)
        base.strokeColor = TerrainStyle.strokeColor(for: displayState.terrain)
        base.lineWidth = displayState.terrain == .fortress ? max(2, layout.hexSize * 0.08) : 1
        base.zPosition = 0
        addChild(base)

        if let controller = displayState.controller {
            addControllerOverlay(path: path, controller: controller, layout: layout)
        }

        if isMoveHighlighted {
            addHighlight(path: path, color: TerrainStyle.movementFill, zPosition: 2)
        }

        if isAttackHighlighted {
            addHighlight(path: path, color: TerrainStyle.attackFill, zPosition: 3)
        }

        if isSelected {
            let selected = SKShapeNode(path: path)
            selected.fillColor = .clear
            selected.strokeColor = TerrainStyle.selectedStroke
            selected.lineWidth = max(3, layout.hexSize * 0.09)
            selected.zPosition = 5
            addChild(selected)
        }

        addObjectiveLabels(
            displayState: displayState,
            supplySourceFaction: supplySourceFaction,
            featureMarkers: featureMarkers,
            layout: layout
        )
        addFog(for: displayState.visibility, path: path)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addHighlight(path: CGPath, color: SKColor, zPosition: CGFloat) {
        let highlight = SKShapeNode(path: path)
        highlight.fillColor = color
        highlight.strokeColor = .clear
        highlight.zPosition = zPosition
        addChild(highlight)
    }

    private func addControllerOverlay(path: CGPath, controller: Faction, layout: HexLayout) {
        let overlay = SKShapeNode(path: path)
        overlay.fillColor = TerrainStyle.controllerColor(for: controller).withAlphaComponent(0.16)
        overlay.strokeColor = TerrainStyle.controllerColor(for: controller).withAlphaComponent(0.82)
        overlay.lineWidth = max(1.5, layout.hexSize * 0.04)
        overlay.zPosition = 1
        addChild(overlay)
    }

    private func addObjectiveLabels(
        displayState: HexDisplayState,
        supplySourceFaction: Faction?,
        featureMarkers: [MapFeatureMarker],
        layout: HexLayout
    ) {
        addFeatureIcons(
            displayState: displayState,
            supplySourceFaction: supplySourceFaction,
            featureMarkers: featureMarkers,
            layout: layout
        )

        if let cityName = displayState.cityName {
            addLabel(
                text: cityName,
                y: -layout.hexSize * 0.04,
                fontSize: max(7, layout.hexSize * 0.18),
                color: TerrainStyle.textColor(for: displayState.terrain),
                zPosition: 6
            )
        }

        if let fortressName = displayState.fortressName {
            addLabel(
                text: fortressName,
                y: -layout.hexSize * 0.04,
                fontSize: max(7, layout.hexSize * 0.16),
                color: TerrainStyle.textColor(for: displayState.terrain),
                zPosition: 6
            )
        }

        if displayState.controller != nil || supplySourceFaction != nil {
            let owner = displayState.controller ?? supplySourceFaction
            let dot = SKShapeNode(circleOfRadius: max(3, layout.hexSize * 0.10))
            dot.fillColor = TerrainStyle.controllerColor(for: owner)
            dot.strokeColor = SKColor(white: 1, alpha: 0.70)
            dot.lineWidth = 1
            dot.position = CGPoint(x: -layout.hexSize * 0.42, y: -layout.hexSize * 0.48)
            dot.zPosition = 7
            addChild(dot)
        }
    }

    private func addFeatureIcons(
        displayState: HexDisplayState,
        supplySourceFaction: Faction?,
        featureMarkers: [MapFeatureMarker],
        layout: HexLayout
    ) {
        if displayState.fortressName != nil || displayState.terrain == .fortress {
            addFortressIcon(layout: layout)
        } else if displayState.cityName != nil || displayState.terrain == .city {
            addCityIcon(layout: layout)
        }

        if let supplySourceFaction {
            addSupplyIcon(faction: supplySourceFaction, layout: layout)
        }

        for marker in featureMarkers where marker.kind.isWaterTransit {
            addWaterTransitIcon(marker: marker, layout: layout)
        }
    }

    private func addCityIcon(layout: HexLayout) {
        let size = max(9, layout.hexSize * 0.26)
        let base = SKShapeNode(rectOf: CGSize(width: size * 0.72, height: size * 0.48), cornerRadius: 1.5)
        base.fillColor = SKColor(red: 0.74, green: 0.55, blue: 0.28, alpha: 0.92)
        base.strokeColor = SKColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 0.95)
        base.lineWidth = max(1, layout.hexSize * 0.025)
        base.position = CGPoint(x: 0, y: layout.hexSize * 0.24)
        base.zPosition = 7
        addChild(base)

        let roofPath = CGMutablePath()
        roofPath.move(to: CGPoint(x: -size * 0.45, y: 0))
        roofPath.addLine(to: CGPoint(x: 0, y: size * 0.30))
        roofPath.addLine(to: CGPoint(x: size * 0.45, y: 0))
        roofPath.closeSubpath()

        let roof = SKShapeNode(path: roofPath)
        roof.fillColor = SKColor(red: 0.55, green: 0.10, blue: 0.08, alpha: 0.94)
        roof.strokeColor = SKColor(red: 0.20, green: 0.08, blue: 0.06, alpha: 0.95)
        roof.lineWidth = max(1, layout.hexSize * 0.025)
        roof.position = CGPoint(x: 0, y: layout.hexSize * 0.47)
        roof.zPosition = 8
        addChild(roof)
    }

    private func addFortressIcon(layout: HexLayout) {
        let size = max(10, layout.hexSize * 0.28)
        let gate = SKShapeNode(rectOf: CGSize(width: size * 0.84, height: size * 0.56), cornerRadius: 1.5)
        gate.fillColor = SKColor(red: 0.27, green: 0.29, blue: 0.30, alpha: 0.95)
        gate.strokeColor = SKColor(red: 0.10, green: 0.11, blue: 0.12, alpha: 1.0)
        gate.lineWidth = max(1, layout.hexSize * 0.03)
        gate.position = CGPoint(x: 0, y: layout.hexSize * 0.24)
        gate.zPosition = 7
        addChild(gate)

        let battlementWidth = size * 0.18
        for index in [-1, 0, 1] {
            let merlon = SKShapeNode(rectOf: CGSize(width: battlementWidth, height: size * 0.24), cornerRadius: 1)
            merlon.fillColor = gate.fillColor
            merlon.strokeColor = gate.strokeColor
            merlon.lineWidth = max(1, layout.hexSize * 0.02)
            merlon.position = CGPoint(
                x: CGFloat(index) * size * 0.28,
                y: layout.hexSize * 0.56
            )
            merlon.zPosition = 8
            addChild(merlon)
        }
    }

    private func addSupplyIcon(faction: Faction, layout: HexLayout) {
        let width = max(11, layout.hexSize * 0.30)
        let height = max(7, layout.hexSize * 0.18)
        let color = TerrainStyle.controllerColor(for: faction)
        let origin = CGPoint(x: layout.hexSize * 0.34, y: layout.hexSize * 0.28)

        for index in 0..<3 {
            let crate = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 1.5)
            crate.fillColor = color.withAlphaComponent(0.82)
            crate.strokeColor = SKColor(red: 0.18, green: 0.13, blue: 0.07, alpha: 0.95)
            crate.lineWidth = max(1, layout.hexSize * 0.02)
            crate.position = CGPoint(
                x: origin.x - CGFloat(index % 2) * width * 0.34,
                y: origin.y + CGFloat(index) * height * 0.46
            )
            crate.zPosition = 9 + CGFloat(index)
            addChild(crate)
        }
    }

    private func addWaterTransitIcon(marker: MapFeatureMarker, layout: HexLayout) {
        switch marker.kind {
        case .ferry:
            addFerryIcon(layout: layout)
        default:
            addPortIcon(layout: layout)
        }
    }

    private func addFerryIcon(layout: HexLayout) {
        let width = max(12, layout.hexSize * 0.32)
        let height = max(6, layout.hexSize * 0.14)
        let y = -layout.hexSize * 0.34

        let hull = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height * 0.35)
        hull.fillColor = SKColor(red: 0.12, green: 0.42, blue: 0.57, alpha: 0.90)
        hull.strokeColor = SKColor(red: 0.05, green: 0.17, blue: 0.22, alpha: 0.95)
        hull.lineWidth = max(1, layout.hexSize * 0.02)
        hull.position = CGPoint(x: layout.hexSize * 0.05, y: y)
        hull.zPosition = 10
        addChild(hull)

        let pole = SKShapeNode(rectOf: CGSize(width: max(1.4, layout.hexSize * 0.03), height: height * 2.3), cornerRadius: 0.6)
        pole.fillColor = SKColor(red: 0.28, green: 0.18, blue: 0.09, alpha: 0.95)
        pole.strokeColor = .clear
        pole.position = CGPoint(x: -width * 0.18, y: y + height * 0.75)
        pole.zPosition = 11
        addChild(pole)
    }

    private func addPortIcon(layout: HexLayout) {
        let size = max(13, layout.hexSize * 0.34)
        let y = -layout.hexSize * 0.32

        let mast = SKShapeNode(rectOf: CGSize(width: max(1.4, layout.hexSize * 0.03), height: size * 0.72), cornerRadius: 0.6)
        mast.fillColor = SKColor(red: 0.18, green: 0.12, blue: 0.07, alpha: 0.95)
        mast.strokeColor = .clear
        mast.position = CGPoint(x: 0, y: y + size * 0.12)
        mast.zPosition = 11
        addChild(mast)

        let sailPath = CGMutablePath()
        sailPath.move(to: CGPoint(x: 0, y: -size * 0.16))
        sailPath.addLine(to: CGPoint(x: size * 0.34, y: size * 0.10))
        sailPath.addLine(to: CGPoint(x: 0, y: size * 0.34))
        sailPath.closeSubpath()

        let sail = SKShapeNode(path: sailPath)
        sail.fillColor = SKColor(red: 0.90, green: 0.95, blue: 0.93, alpha: 0.92)
        sail.strokeColor = SKColor(red: 0.05, green: 0.17, blue: 0.22, alpha: 0.95)
        sail.lineWidth = max(1, layout.hexSize * 0.02)
        sail.position = CGPoint(x: 0, y: y + size * 0.12)
        sail.zPosition = 12
        addChild(sail)

        let hull = SKShapeNode(rectOf: CGSize(width: size * 0.70, height: size * 0.16), cornerRadius: size * 0.06)
        hull.fillColor = SKColor(red: 0.12, green: 0.42, blue: 0.57, alpha: 0.90)
        hull.strokeColor = sail.strokeColor
        hull.lineWidth = max(1, layout.hexSize * 0.02)
        hull.position = CGPoint(x: 0, y: y - size * 0.22)
        hull.zPosition = 12
        addChild(hull)
    }

    private func addFog(for visibility: VisibilityState, path: CGPath) {
        let alpha: CGFloat
        switch visibility {
        case .visible:
            return
        case .explored:
            alpha = 0.34
        case .unseen:
            alpha = 0.72
        }

        let fog = SKShapeNode(path: path)
        fog.fillColor = SKColor(white: 0.04, alpha: alpha)
        fog.strokeColor = .clear
        fog.zPosition = 20
        addChild(fog)
    }

    private func addLabel(text: String, y: CGFloat, fontSize: CGFloat, color: SKColor, zPosition: CGFloat) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = fontSize
        label.fontColor = color
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: y)
        label.zPosition = zPosition
        addChild(label)
    }

    private static func hexPath(layout: HexLayout) -> CGPath {
        let points = layout.polygonPoints(center: .zero)
        let path = CGMutablePath()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}
