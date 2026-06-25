public class Layer: _BaseLayer {
    public override var shape: any ShapeProtocol {
        Shape.rect(
            width: size.x, height: size.y, cornerRadius: cornerRadius, cornerDegree: cornerDegree)
    }

    public var opacity: Float = 1 {
        didSet { dirtyFlags.insert(.grouping) }
    }

    public var brush: CompositionBrush = .solid(.transparent) {
        didSet { dirtyFlags.insert(.contents) }
    }
    public var cornerRadius: Float = 0 {
        didSet { dirtyFlags.insert(.contents) }
    }
    public var cornerDegree: Float = 4 {
        didSet { dirtyFlags.insert(.contents) }
    }

    public var borderWidth: Float = 0 {
        didSet { dirtyFlags.insert(.contents) }
    }
    public var borderBrush: CompositionBrush = .solid(.transparent) {
        didSet { dirtyFlags.insert(.contents) }
    }

    public var shadowOffset: SIMD2<Float> = .zero {
        didSet { dirtyFlags.insert(.contents) }
    }
    public var shadowBlur: Float = 0 {
        didSet { dirtyFlags.insert(.contents) }
    }
    public var shadowSpread: Float = 0 {
        didSet { dirtyFlags.insert(.contents) }
    }
    public var shadowColor: Color = .black {
        didSet { dirtyFlags.insert(.contents) }
    }
    public var shadowOpacity: Float = 0 {
        didSet { dirtyFlags.insert(.contents) }
    }

    override var isRasterizationRoot: Bool {
        shouldRasterize || (opacity != 0 && opacity != 1)
    }
}
