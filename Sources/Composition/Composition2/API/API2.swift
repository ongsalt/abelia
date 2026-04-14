enum APIDesign {}

extension APIDesign {
    class Node {  // basically SpriteVisual -> currently our CompositionNode
        // transform/offset/opacity
        var parent: Node?
        var children: [Node] = []

        var comment: String?
        var brush: Brush?

        var shouldRasterize: Bool = false
        // we need to calculate Bounding Box + shadow + border and shit

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

    class ShapeNode: Node {  // new node that wont ever cache its content.
        struct Shape {
            let brush: Brush
            // let kind
        }
    }

    class ScrollNode: Node {  // only redraw diff
    }

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
        case gradient(Gradient)  // -> image/gradient1d/vertex interpolation
        case image(any Surface, ninegrid: SIMD4<Float>, crop: SIMD4<Float>)
        // well well well, this still require grouping node into layer
        // and this shouldnt sample layer outside its rasterizationRoot anyways
        // this is the current behavior
        case effect([ImageFilter])  // -> image
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

public struct DirtyFlags: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let source = DirtyFlags(rawValue: 1 << 0)
    public static let overlapped = DirtyFlags(rawValue: 1 << 1)
}

extension DirtyFlags {
    var shouldUpdate: Bool {
        rawValue != 0
    }
}
