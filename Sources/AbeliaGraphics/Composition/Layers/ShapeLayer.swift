public class ShapeLayer: Layer {
    var shapes: [CompositionShape] = []
}

struct CompositionShape {
    public var opacity: Float = 1
    public var brush: CompositionBrush? = .solid(.red)
    public var border: Border?
    public var shadow: Shadow?
    public var shape: (any ShapeProtocol)?
    public var affine: Affine?
}
