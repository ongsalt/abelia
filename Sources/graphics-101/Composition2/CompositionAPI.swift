// THIS SHIT BETTER BE IN RUST

// This is only the api not actual object managed by the framework
class _Layer {
    var scale: Float = 1
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
    private var shouldActuallyRasterize: Bool {
        shouldRasterize || _shouldRasterize
    }
}

// we have 16 vertex attr * 16 bytes -> 256 bytes -> 64 float
// 1. opacity, screenSize.{w,h}
//  should we move this into affine matrix
// 2. position.{x,y}, size.{w,h}
// 3-6. Affine matrix (16 float)

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
}
// this one must have its own shader type
// Its SDF rect tho 
// 7. cornerRadius.{x,y,z,w}
// 8. cornerDegree, borderWidth, [8 bytes]
// 9-11. Colors: shadow, fill, border
// 12. shadow: offset.{x.y}, blur, spread

class SurfaceLayer {
    var contents: Surface?
    var ninegrid: SIMD4<Float> = .zero

    func invalidate() {}
}
// for other complicate shi pls use skia
// TODO:
// in simpler case we can just put this into Rect shader
// 7. hasContent, contentIndex: u32,
// 8. ninegrid (rect.{top, left, bottom, right})


class BackdropEffectLayer: ContainerLayer {
    let filters: [ImageFilter] = []
}
// this might be dispatch to multiple shader
// one thing all of these have in common is that they require layer underneath to be rasterized
// This can be done in composite phase

enum ImageFilter {
    case blendMode(BlendMode)
    case gaussianBlur(radius: Float, edgeSampling: EdgeSamplingMethod = .repeat)
    case material(MaterialType) // very opinionate
    case dither
}

enum EdgeSamplingMethod  {
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
}

// most ui is rect anyway


// So final part of pipeline is always composite phase
/// Render pipeline
/// - someone request redraw (wayland frame timing?) with damaged layers list
/// proc raster(root):
///   get render surface
///   walk layer tree starting from root
///     - root layer must always be raster
///     - skip every shouldRaster layer that is not damaged
///     - if damaged -> raster(said node)
/// should we still do damaged rect at this point
/// TODO: just test compositing speed in vulkan-rust