public class Layer: _BaseLayer {
    public override var shape: any ShapeProtocol {
        Shape.rect(
            width: size.x, height: size.y, cornerRadius: cornerRadius, cornerDegree: cornerDegree)
    }

    public var opacity: Float = 1 {
        didSet { dirtyFlags.insert(.grouping) }
    }

    public var brush: CompositionBrush? {
        didSet { dirtyFlags.insert(.contents) }
    }
    public var cornerRadius: Float = 0 {
        didSet { dirtyFlags.insert(.contents) }
    }
    public var cornerDegree: Float = 4 {
        didSet { dirtyFlags.insert(.contents) }
    }

    public var border: Border? {
        didSet { dirtyFlags.insert(.contents) }
    }

    public var shadow: Shadow? {
        didSet { dirtyFlags.insert(.contents) }
    }

    override var isRasterizationRoot: Bool {
        shouldRasterize || (opacity != 0 && opacity != 1)
    }
}

public struct Border {
    public var width: Float = 1
    public var brush: CompositionBrush = .solid(.black)
}

public struct Shadow {
    public var offset: SIMD2<Float> = .zero
    public var blur: Float = 15
    public var spread: Float = 0
    public var color: Color = .black
    public var opacity: Float = 75
}
