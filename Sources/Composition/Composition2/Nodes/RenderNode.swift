// this doesnt actually exist in shader, only
class RenderNode: Identifiable {
    weak var compositor: Compositor? {
        didSet {
            for c in children {
                c.compositor = compositor
            }
        }
    }
    var parent: RenderNode?
    var children: [RenderNode] = []

    // its wrong
    public var scale: SIMD2<Float> = .one {
        didSet {
            markDirty()
        }
    }
    public var rotation: Float = 0 {
        didSet {
            markDirty()
        }
    }
    public var opacity: Float = 1 {
        didSet {
            markDirty()
        }
    }
    public var isHidden: Bool = false {
        didSet {
            markDirty()
        }
    }
    public var position: SIMD2<Float> = .zero {
        didSet {
            markDirty()
        }
    }
    public var size: SIMD2<Float> = .zero {
        didSet {
            markDirty()
        }
    }
    public var affine: AffineMatrix = .identity {
        didSet {
            markDirty()
        }
    }
    // public var drawBackface: Bool = true

    public var shouldRasterize: Bool = false {
        didSet {
            markDirty()
        }
    }
    // will be set when doing opacity/animation
    // the framework might decide if it is a dependency of foreground effect
    var _shouldRasterize: Bool = false {
        didSet {
            markDirty()
        }
    }

    var dirty: Bool = true
    public func markDirty() {
        dirty = true
        if let parent {
            // if !parent.dirty {
            parent.markDirty()
            // }
        }
    }

    public func markClean() {
        dirty = false
        for c in children {
            c.markClean()
        }
    }

    public func addChild(_ children: RenderNode...) {
        for c in children {
            c.parent = self
            c.compositor = compositor
        }

        self.children.append(contentsOf: children)
        markDirty()
    }

    public func removeChild(child: RenderNode) {
        self.children.removeAll { $0.id == child.id }
        child.parent = nil
        child.compositor = nil
        markDirty()
    }
}

extension RenderNode {
    var isRasterizationRoot: Bool {
        (shouldRasterize || _shouldRasterize || (opacity != 1 && opacity != 0)) && !children.isEmpty
        // we can actually keep the rasterrized texture for a while for fade animation
    }

    // size including transformation and shadow

    var rasterizationRoot: RenderNode {
        guard let parent else {
            return self  // this wont happen
        }
        if self.isRasterizationRoot {
            return self
        }
        return parent.rasterizationRoot
    }

    var totalAffine: AffineMatrix {
        (parent?.totalAffine ?? AffineMatrix.identity)
            .scaled(x: scale.x, y: scale.y, z: 1.0)
            .rotated(angleRadians: rotation, axis: SIMD3(0, 0, 1))
            .then(affine)
    }

    // TODO: properly calculate transformed bounds
    var transformedPosition: SIMD2<Float> {
        position
    }

    var absolutePosition: SIMD2<Float> {
        if let parent {
            parent.absolutePosition + transformedPosition
        } else {
            .zero
        }
    }

    var rootRelativePosition: SIMD2<Float> {
        if let parent {
            if parent.isRasterizationRoot {
                transformedPosition
            } else {
                parent.rootRelativePosition + transformedPosition
            }
        } else {
            .zero
        }
    }

    var absoluteRect: Rect {
        Rect(topLeft: absolutePosition, size: size * scale)
    }

    func print(indentation: Int = 0) {
        let i = String(repeating: " ", count: indentation)
        Swift.print(
            i + "- \(Self.self) \(isRasterizationRoot ? "[root]" : ""): \(self.absoluteRect)")
        for c in self.children {
            c.print(indentation: indentation + 2)
        }
    }
}

// now its vertex buffer not input, shuold this be HOST_COHERANT?? its gonna update a lot
// old vertex input -> perVertexData (localPos, dataIndex)
//                  -> sharedVertexData
// both of these can be in a InputBuffer

// fragment shader input: push_constant, (current) texture list,

// we have 16 vertex attr * 16 bytes -> 256 bytes -> 64 float
// 0. opacity, screenSize.{w,h}, mode (0=shape, 1=shadow)
// 1. position.{x,y}, size.{w,h}
//  - should we move this into affine matrix
// 2-5. Affine matrix (16 float)

// this one must have its own shader type
// Its SDF rect tho
// 6. cornerRadius.{x,y,z,w}
// 7. cornerDegree, borderWidth, vertexLocalPos.{x,y}
// 8. Colors: color (shape fill or shadow color)
// 9. Colors: border color
// 10. shadow: offset.{x,y}, blur, spread
// 11. contents: hasContent, contentIndex: u32, contentAux0, contentAux1
// 12. ninegrid (rect.{top, left, bottom, right})
//
// always clip immediate contents, clip chlid contents only when rasterize: true
//

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
