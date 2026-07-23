import CShim
import Vulkan

// or we rewrite this every frame?

// 1 to 1 with shader data (in term of information not layout)
// This should be swift struct
// sdf is center-anchor, this is mainly 2d, so on fast path (no 3d) we shouldnot do any matrix math on the cpu at all
public struct RenderNode: Sendable {
    public var brush: Brush = .solid(.transparent)
    public var shape: any ShapeProtocol = Shape.rect(width: 0, height: 0)

    public var border: NodeBorder?
    public var shadow: NodeShadow?

    /// Ancestor clip shapes, each in the same (pass/world) space as `affine`. The fragment is kept
    /// only where it is inside *all* of them (their SDF intersection). Reuses the shape merge buffer.
    public var clip: ClipStack = .empty

    public var opacity: Float = 1
    // TODO: backfaceVisibility, might just filter out
    public var affine: Affine = .identity
}

/// A single clip shape plus the transform placing it into pass/world space (shape-local -> world).
public struct ClipShape: Sendable {
    public var shape: any ShapeProtocol
    public var transform: Transform2D

    public init(shape: any ShapeProtocol, transform: Transform2D) {
        self.shape = shape
        self.transform = transform
    }
}

/// A resolved clip stack, shared by reference across every node it applies to. Because sibling nodes
/// point at the *same* instance, the renderer can write its merge program to the shape buffer once
/// per frame and key the run by object identity — instead of duplicating it per node.
public final class ClipStack: @unchecked Sendable {
    public let shapes: [ClipShape]
    public var isEmpty: Bool { shapes.isEmpty }

    public init(_ shapes: [ClipShape]) { self.shapes = shapes }
    public static let empty = ClipStack([])
}

public struct NodeShadow: Sendable {
    public var offset: SIMD2<Float> = .zero
    public var blur: Float = 15
    public var spread: Float = 0
    public var color: Color = .black
    public var opacity: Float = 65
}

public struct NodeBorder: Sendable {
    public var width: Float = 1
    public var brush: Brush = .solid(Color.black.with(alpha: 0.3))
}
