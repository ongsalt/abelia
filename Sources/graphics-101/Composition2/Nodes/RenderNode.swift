// this doesnt actually exist in shader, only
class RenderNode {
    private(set) var parent: RenderNode?
    var children: [RenderNode] = []

    public var scale: SIMD2<Float> = .one {
        didSet {
            // invalidate()
        }
    }
    public var rotation: Float = 0
    public var opacity: Float = 1
    public var isHidden: Bool = false
    public var position: SIMD2<Float> = .zero
    public var size: SIMD2<Float> = .zero
    public var affine: AffineMatrix = .identity
    // public var drawBackface: Bool = true

    public var shouldRasterize: Bool = false
    // will be set when doing opacity/animation
    // the framework might decide if it is a dependency of foreground effect
    package var _shouldRasterize: Bool = false
    package var isRasterizationRoot: Bool {
        shouldRasterize || _shouldRasterize || (opacity != 1 && opacity != 0)
        // we can actually keep the rasterrized texture for a while for fade animation
    }

    package var dirty: Bool = true
    public func markDirty() {
        dirty = true
    }

}

extension RenderNode {
    package var rasterizationRoot: RenderNode {
        guard let parent else {
            return self  // this wont happen
        }
        if self.isRasterizationRoot {
            return self
        }
        return parent.rasterizationRoot
    }

    package var totalAffine: AffineMatrix {
        AffineMatrix
            .identity
            .scaled(x: scale.x, y: scale.y, z: 1.0)
            .rotated(angleRadians: rotation, axis: SIMD3(0, 0, 1))
            .then(affine)
    }

    // TODO: properly calculate transformed bounds
    package var transformedPosition: SIMD2<Float> {
        position
    }

    package var absolutePosition: SIMD2<Float> {
        if let parent {
            parent.absolutePosition + transformedPosition
        } else {
            .zero
        }
    }

    package var absoluteRect: Rect {
        Rect(topLeft: absolutePosition, size: size * scale)
    }
}

// we have 16 vertex attr * 16 bytes -> 256 bytes -> 64 float
// 0. opacity, screenSize.{w,h}
// 1. position.{x,y}, size.{w,h}
//  - should we move this into affine matrix
// 2-5. Affine matrix (16 float)

// this one must have its own shader type
// Its SDF rect tho
// 6. cornerRadius.{x,y,z,w}
// 7. cornerDegree, borderWidth, [8 bytes]
// 8-10. Colors: fill, shadow, border
// 11. shadow: offset.{x.y}, blur, spread
// 12. hasContent, contentIndex: u32, hasMask, maskIndex: u32
// 13. ninegrid (rect.{top, left, bottom, right})
// 14. layer mask
// always clip immediate contents, clip chlid contents only when rasterize: true
//

/// TODO: mode
/// Shadow should be in seperated mode (so we can sort it)
/// how do we expose this api tho shadowZ: [normal|bottom]
/// Mode, 1 layer -> >1 draw commmands
/// - sampling: ninegrid, contentIndex
///     - colored
///     - tinted (text)
/// - rect: fill, stroke, shadow
/// shadow will be excluded when drawing to self-owned layer
///  -> so shuold fill and stroke?
///
/// Shared options
/// - clipping
///     - sizing
///     - corner
///     - border width
///
/// Shadow of arbitrary shape -> fucking blur it
