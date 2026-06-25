import CShim
import Vulkan

// or we rewrite this every frame?

// 1 to 1 with shader data (in term of information not layout)
// This should be swift struct
public struct RenderNode {
    public var brush: Brush = .solid(.transparent)
    public var shape: any ShapeProtocol = Shape.rect(width: 0, height: 0)

    public var borderWidth: Float = 0
    public var borderBrush: Brush = .solid(.transparent)

    public var shadowOffset: SIMD2<Float> = .zero
    public var shadowBlur: Float = 0
    public var shadowSpread: Float = 0
    public var shadowColor: Color = .black
    public var shadowOpacity: Float = 0

    // TODO: backfaceVisibility
    public var affine: Affine = .identity

    // TODO: write this
    public var bounds: Rect = .unit
}
