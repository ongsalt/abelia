public class ShapeLayer: _BaseLayer {
    public var shapes: [ShapeItem] = []
}

public struct ShapeItem {
    public var shape: any ShapeProtocol
    public var brush: CompositionBrush
    public var border: Border?
    public var shadow: Shadow?
    public var opacity: Float
    public var offset: SIMD3<Float>
    public var rotation: Angle
    public var rotationAxis: SIMD3<Float>
    public var scale: SIMD2<Float>

    public init(
        shape: any ShapeProtocol,
        brush: CompositionBrush,
        border: Border? = nil,
        shadow: Shadow? = nil,
        opacity: Float = 1,
        offset: SIMD3<Float> = .zero,
        rotation: Angle = .radians(0),
        rotationAxis: SIMD3<Float> = [0, 0, 1],
        scale: SIMD2<Float> = .one
    ) {
        self.shape = shape
        self.brush = brush
        self.border = border
        self.shadow = shadow
        self.opacity = opacity
        self.offset = offset
        self.rotation = rotation
        self.rotationAxis = rotationAxis
        self.scale = scale
    }
}
