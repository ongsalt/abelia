import CShim
import Vulkan

// or we rewrite this every frame?

// 1 to 1 with shader data (in term of information not layout)
// This should be swift struct
// sdf is center-anchor
public struct RenderNode: Sendable {
    public var brush: Brush = .solid(.transparent)
    public var shape: any ShapeProtocol = Shape.rect(width: 0, height: 0)

    public var border: NodeBorder?
    public var shadow: NodeShadow?

    public var opacity: Float = 1
    // TODO: backfaceVisibility
    public var affine: Affine = .identity
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
