// THIS SHIT BETTER BE IN RUST

// This is only the api not actual object managed by the framework
class _Layer {
    private(set) var parent: _Layer?
    var scale: Float = 1 {
        didSet {
            // invalidate()
        }
    }
    var rotation: Float = 0
    var opacity: Float = 1
    var isHidden: Bool = false
    var position: SIMD2<Float> = .zero
    var size: SIMD2<Float> = .zero
    var affine: AffineMatrix = .identity

    var drawBackface: Bool = true
    var shouldRasterize: Bool = false

    // will be set when doing opacity/animation
    // the framework might decide if it is a dependency of foreground effect
    package var _shouldRasterize: Bool = false
    package var shouldActuallyRasterize: Bool {
        shouldRasterize || _shouldRasterize || (opacity != 1 && opacity != 0)
        // we can actually keep the rasterrized texture for a while for fade animation
    }
}

extension _Layer {
    var rasterizationRoot: _Layer {
        guard let parent else {
            return self  // this wont happen
        }
        if self.shouldActuallyRasterize {
            return self
        }
        return parent.rasterizationRoot
    }
}

// we have 16 vertex attr * 16 bytes -> 256 bytes -> 64 float
// 0. opacity, screenSize.{w,h}
//  should we move this into affine matrix
// 1. position.{x,y}, size.{w,h}
// 2-5. Affine matrix (16 float)

class RectLayer: ContainerLayer {
    var cornerRadius: Float = 0
    var cornerDegree: Float = 0

    var shadowColor: Color = .transparent
    var shadowBlur: Float = 0
    var shadowOffset: SIMD2<Float> = .zero
    var shadowSpread: Float = 0

    var borderColor: Color = .transparent
    var borderWidth: Float = 0

    var fillColor: Color = .transparent
    // var scalingMode:

    var contents: Surface?
    var ninegrid: SIMD4<Float> = .zero

    func invalidateContents() {}
}
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

class EffectLayer: _Layer {
    let filters: [ImageFilter] = []
    override var shouldActuallyRasterize: Bool { true }
}
// this might be dispatch to multiple shader
// one thing all of these have in common is that they require layer underneath to be rasterized
// Or we nuke this class and make this a property of a _Layer then the framework just flag it

enum ImageFilter {
    case blendMode(BlendMode)
    case gaussianBlur(radius: Float, edgeSampling: EdgeSamplingMethod = .repeat)
    case toneMap
    case material(MaterialType)  // very opinionate
    case dither
}

enum EdgeSamplingMethod {
    case `repeat`
    case transparent
}

enum MaterialType {
    case idkMan
}

enum BlendMode {
    case overlay
    case multiply
    case add
    case subtract
}

protocol Surface {}

class ContainerLayer: _Layer {
    // private var _children: [Layer] = []

    var _children: [_Layer] = []
    // shuold be linked list ?
}
