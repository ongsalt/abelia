enum APIDesign {}

extension APIDesign {
    class Node {  // basically SpriteVisual -> currently our CompositionNode
        // transform/offset/opacity
        var comment: String?
        var brush: Brush?

        var shouldRasterize: Bool = false
    }

    class ShapeNode: Node {  // new node that wont ever cache its content.
        struct Shape {
            let brush: Brush
            // let kind
        }
    }

    // // this will rasterize its content to a offscreen texture before composite
    // // basically flutter RepaintBoundary
    // class RasterizedLayer: Node {

    // }

    struct DropShadow {
        var color: Color
        var opacity: Float
        var blur: Float
        var renderMode: RenderMode = .sdf

        enum RenderMode {
            // case path(Path)
            case sdf  // based on parent Node
            case content  // look at content pixel coverage and fucking blur it
        }
    }

    enum Brush {
        case solid(Color)
        case gradient(Gradient) // -> image/gradient1d/vertex interpolation
        case image(any Surface, ninegrid: SIMD4<Float>, crop: SIMD4<Float>)
        // well well well, this still require grouping node into layer
        // and this shouldnt sample layer outside its rasterizationRoot anyways
        // this is the current behavior
        case effect([ImageFilter]) // -> image
    }

    // 1d texture lookup for simple case
    //  might fallback to Vertex Color Interpolation
    struct Gradient {}

    protocol Surface {}

    struct Path {}
}

// this is kinda complex we might need proper render graph now

enum IntermediateNode {
    enum Pipeline {
        // uber shader
        //  - draw shape with brush mainly
        //  - currently our CompositionNode
        //  - gonna add ability to draw shape later?
        //  - effect (but there are too many effect)
        // brush mode
        // - solid
        // - gradient1d(source)
        // - image(source, ninegrid, crop)
        case main
        case gradient1d
        // case custom(Shader)
    }

    enum RenderTask {
        case shape
        case shadow
        case gradient1d
        // case gradient2d
        case effect

        case textureLoading

        var pipeline: Pipeline? {
            switch self {
            case .shape: .main
            case .shadow: .main
            case .gradient1d: .gradient1d
            case .effect: .main
            case .textureLoading: nil
            }
        }
    }
}
