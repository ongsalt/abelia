import AbeliaGraphics
import Foundation

/// Interactive card that tilts in 3d toward the cursor (css-style hover tilt),
/// showing off the unary sdf ops: `.onion` (rings) and `.rounded` (puffed shapes).
@MainActor
final class TiltCardScene {
    let card: ShapeLayer
    private let compositor: Compositor
    /// (rotation about x, rotation about y) in radians
    private let tilt: SpringAnimator<Vec2<Float>>

    private let cardSize: SIMD2<Float> = [260, 360]
    private let maxTilt: Float = .pi / 14
    private let hoverMargin: Float = 24

    init(
        compositor: Compositor,
        controller: CompositorAnimationController,
        bounds: SIMD2<Float>
    ) {
        self.compositor = compositor
        self.card = ShapeLayer(size: cardSize)
        self.tilt = SpringAnimator(
            value: .zero,
            configuration: SpringConfiguration(response: 0.35, dampingRatio: 0.72),
            controller: controller
        )

        // pivot the tilt at the card center
        card.transformOrigin = cardSize / 2
        updateBounds(bounds)
        refreshShapes()
        compositor.requestAnimationFrame(callback: tick)
    }

    func updateBounds(_ bounds: SIMD2<Float>) {
        card.offset = SIMD3(
            max(bounds.x - cardSize.x - 60, 0),
            max((bounds.y - cardSize.y) / 2, 0),
            0
        )
    }

    func pointerMoved(_ p: Vec2<Float>) {
        let half = cardSize / 2
        let center = SIMD2(card.offset.x, card.offset.y) + half
        let d = SIMD2(p.x, p.y) - center

        guard abs(d.x) <= half.x + hoverMargin, abs(d.y) <= half.y + hoverMargin else {
            tilt.value = .zero
            return
        }

        let nx = min(max(d.x / half.x, -1), 1)
        let ny = min(max(d.y / half.y, -1), 1)
        // pitch toward the cursor's vertical offset, yaw toward its horizontal one
        tilt.value = Vec2(-ny * maxTilt, nx * maxTilt)
    }

    private func tick() {
        refreshTransform()
        refreshShapes()
        compositor.requestAnimationFrame(callback: tick)
    }

    private func refreshTransform() {
        let t = tilt.value
        let magnitude = (t.x * t.x + t.y * t.y).squareRoot()
        if magnitude < 1e-4 {
            card.rotation = .radians(0)
            card.rotationAxis = [0, 0, 1]
        } else {
            // small-angle composition of rotateX(t.x)·rotateY(t.y) as one axis-angle
            card.rotation = .radians(magnitude)
            card.rotationAxis = SIMD3(-t.x / magnitude, -t.y / magnitude, 0)
        }
    }

    private func refreshShapes() {
        let c = cardSize / 2
        let t = tilt.value
        // shadow slides opposite the tilt so the card reads as lit from the front
        let shadowShift = SIMD2(-t.y, t.x) * 140

        card.shapes = [
            ShapeItem(
                shape: Shape.rect(width: cardSize.x, height: cardSize.y, cornerRadius: 28),
                brush: .solid(Color(red: 0.98, green: 0.97, blue: 0.94)),
                shadow: Shadow(offset: shadowShift, blur: 48, opacity: 0.3),
                offset: SIMD3(c.x, c.y, 0)
            ),
            // onion on a rounded rect = thin inset frame
            ShapeItem(
                shape: Shape.rect(width: cardSize.x - 26, height: cardSize.y - 26, cornerRadius: 20)
                    .onion(1),
                brush: .solid(.black.with(alpha: 0.15)),
                offset: SIMD3(c.x, c.y, 0)
            ),
            // onion of onion — two concentric rings from one circle
            ShapeItem(
                shape: Shape.circle(30).onion(9).onion(2.5),
                brush: .solid(.teal),
                offset: SIMD3(64, 74, -18)
            ),
            // hexagon outline via onion
            ShapeItem(
                shape: Shape.hexagon(radius: 26).onion(4),
                brush: .solid(.indigo),
                offset: SIMD3(cardSize.x - 64, 74, -18)
            ),
            // hero: pentagram puffed out by rounded — plush star
            ShapeItem(
                shape: Shape.pentagram(radius: 52).rounded(14),
                brush: .solid(.orange),
                shadow: Shadow(offset: shadowShift * 0.5, blur: 24, opacity: 0.25),
                offset: SIMD3(c.x, 185, -34)
            ),
            // hexagram ring — onion on a star
            ShapeItem(
                shape: Shape.hexagram(radius: 24).onion(3),
                brush: .solid(.pink),
                offset: SIMD3(64, 282, -18)
            ),
            // "text" lines: hairline rects puffed into capsules by rounded
            ShapeItem(
                shape: Shape.rect(width: 110, height: 1).rounded(6),
                brush: .solid(.black.with(alpha: 0.3)),
                offset: SIMD3(166, 276, -10)
            ),
            ShapeItem(
                shape: Shape.rect(width: 170, height: 1).rounded(5),
                brush: .solid(.black.with(alpha: 0.18)),
                offset: SIMD3(c.x, 322, -10)
            ),
        ]
    }
}
