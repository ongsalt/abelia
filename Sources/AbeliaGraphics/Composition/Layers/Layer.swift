import ReactivityGraph

public class Layer: _BaseLayer {
    public override var shape: any ShapeProtocol {
        Shape.rect(
            width: size.x, height: size.y, cornerRadius: cornerRadius, cornerDegree: cornerDegree)
    }

    @Bindable
    public var opacity: Float = 1 {
        didSet { dirtyFlags.insert(.compositionGroup) }
    }

    @Bindable
    public var brush: CompositionBrush? {
        didSet { dirtyFlags.insert(.draw) }
    }

    @Bindable
    public var cornerRadius: Float = 0 {
        didSet { dirtyFlags.insert(.draw) }
    }

    @Bindable
    public var cornerDegree: Float = 4 {
        didSet { dirtyFlags.insert(.draw) }
    }

    @Bindable
    public var border: Border? {
        didSet { dirtyFlags.insert(.draw) }
    }

    @Bindable
    public var shadow: Shadow? {
        didSet { dirtyFlags.insert(.draw) }
    }

    override var isCompositionGroupRoot: Bool {
        shouldRasterize || (opacity != 0 && opacity != 1) || shuoldClipStartCompositionGroup
    }
}

public struct Border {
    public var width: Float = 1
    public var brush: CompositionBrush = .solid(Color.black.with(alpha: 0.3))

    public init(
        width: Float = 1,
        brush: CompositionBrush = .solid(Color.black.with(alpha: 0.3))
    ) {
        self.width = width
        self.brush = brush
    }
}

public struct Shadow {
    public var offset: SIMD2<Float> = .zero
    public var blur: Float = 15
    public var spread: Float = 0
    public var color: Color = .black
    public var opacity: Float = 0.65

    public init(
        offset: SIMD2<Float> = .zero, blur: Float = 15, spread: Float = 0, color: Color = .black,
        opacity: Float = 0.65
    ) {
        self.offset = offset
        self.blur = blur
        self.spread = spread
        self.color = color
        self.opacity = opacity
    }
}
