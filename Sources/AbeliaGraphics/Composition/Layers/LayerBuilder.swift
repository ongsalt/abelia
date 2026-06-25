@resultBuilder
public struct LayerBuilder {
    public static func buildBlock(_ layers: _BaseLayer...) -> [_BaseLayer] { layers }
    public static func buildArray(_ layers: [[_BaseLayer]]) -> [_BaseLayer] {
        layers.flatMap { $0 }
    }
    public static func buildOptional(_ layers: [_BaseLayer]?) -> [_BaseLayer] { layers ?? [] }
    public static func buildEither(first layers: [_BaseLayer]) -> [_BaseLayer] { layers }
    public static func buildEither(second layers: [_BaseLayer]) -> [_BaseLayer] { layers }
}

extension _BaseLayer {
    public convenience init(
        offset: SIMD3<Float> = .zero,
        @LayerBuilder children: () -> [_BaseLayer] = { [] }
    ) {
        self.init()
        self.offset = offset
        for child in children() {
            insert(child)
        }
    }
}

extension Layer {
    public convenience init(
        offset: SIMD3<Float> = .zero,
        size: SIMD2<Float> = .zero,
        opacity: Float = 1,
        brush: CompositionBrush = .solid(.transparent),
        cornerRadius: Float = 0,
        cornerDegree: Float = 4,
        borderWidth: Float = 0,
        borderBrush: CompositionBrush = .solid(.transparent),
        shadowOffset: SIMD2<Float> = .zero,
        shadowBlur: Float = 0,
        shadowSpread: Float = 0,
        shadowColor: Color = .black,
        shadowOpacity: Float = 0,
        @LayerBuilder children: () -> [_BaseLayer] = { [] }
    ) {
        self.init()
        self.offset = offset
        self.size = size
        self.opacity = opacity
        self.brush = brush
        self.cornerRadius = cornerRadius
        self.cornerDegree = cornerDegree
        self.borderWidth = borderWidth
        self.borderBrush = borderBrush
        self.shadowOffset = shadowOffset
        self.shadowBlur = shadowBlur
        self.shadowSpread = shadowSpread
        self.shadowColor = shadowColor
        self.shadowOpacity = shadowOpacity
        for child in children() {
            insert(child)
        }
    }
}
