// 1d texture lookup for simple case
//  might fallback to Vertex Color Interpolation

// this is kinda complex we might need proper render graph now

enum APIDesign {}
extension APIDesign {
    class Layer {  // basically SpriteVisual -> currently our CompositionLayer
        // transform/offset/opacity
        var parent: Layer?
        var children: [Layer] = []

        var comment: String?
        var brush: Brush?

        var shouldRasterize: Bool = false
        // we need to calculate Bounding Box + shadow + border and shit

        // advance blend mode: for device with dynamic_rendering_local_read OR blend_operation_advanced???

        // var flags: DirtyFlags = .dirty
        // func markDirty() {
        //     // if compositor.localThreadState.isRendering {
        //     //     flags.insert(.outdated)
        //     // } else {
        //     //     flags.insert(.dirty)
        //     // }
        // }

        // func markClean() {
        //     if flags.contains(.outdated) {
        //         flags = .dirty
        //     } else {
        //         flags = []
        //     }
        //     for c in children {
        //         c.markClean()
        //     }
        // }
    }

    class ShapeLayer: Layer {  // new Layer that wont ever cache its content.
        struct Shape {
            let brush: Brush
            // let kind
        }
    }

    class ScrollLayer: Layer {  // only redraw diff
    }

    struct DropShadow {
        var color: Color
        var blur: Float
        var renderMode: RenderMode = .sdf

        enum RenderMode {
            // case path(Path)
            case sdf  // based on parent Layer
            case content  // look at content pixel coverage and fucking blur it
        }
    }

    struct Path {}
}
public enum Brush {  // 4f, 1f (index), imageIndex:4f:4f, ONEeffect(max=8f):samplerIndex
    // so 1f tag + 9f for brush
    case solid(Color)
    // case gradient(Gradient)  // -> image/gradient1d/vertex interpolation
    
    // this should be auto register
    case image(any CompositionTextureProtocol, ninegrid: SIMD4<Float>, crop: SIMD4<Float>)
    // well well well, this still require grouping Layer into layer
    // and this shouldnt sample layer outside its rasterizationRoot anyways
    // this is the current behavior
    case effect(ImageFilter)  // -> image
}
extension Brush {
    var isEffect: Bool {
        switch self {
        case .effect:
            true
        default:
            false
        }
    }
}
public struct Gradient {}
public protocol CompositionTextureProtocol {
    var textureIndex: UInt32 { get }
}
public enum ImageFilter {
    case blur(radius: Float)
    case colorMatrix(AffineMatrix)
}
public enum BlendMode {

}
enum IntermediateLayer {
    enum Pipeline {
        // uber shader
        //  - draw shape with brush mainly
        //  - currently our CompositionLayer
        //  - gonna add ability to draw shape later?
        //  - effect (but there are too many effect)
        // brush mode
        // - solid
        // - gradient1d(source)
        // - image(source, ninegrid, crop)
        case main

        // case gradient1d
        // case custom(Shader)
    }
}
public struct DirtyFlags: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Need to update gpu buffer
    public static let source = DirtyFlags(rawValue: 1 << 0)

    /// No need, just for propagation
    public static let parent = DirtyFlags(rawValue: 1 << 1)
}
extension DirtyFlags {
    var shouldUpdate: Bool {
        !self.isEmpty
    }
}
