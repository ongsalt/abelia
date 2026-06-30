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
        brush: CompositionBrush? = nil,
        cornerRadius: Float = 0,
        cornerDegree: Float = 4,
        border: Border? = nil,
        shadow: Shadow? = nil,
        @LayerBuilder children: () -> [_BaseLayer] = { [] }
    ) {
        self.init()
        self.offset = offset
        self.size = size
        self.opacity = opacity
        self.brush = brush
        self.cornerRadius = cornerRadius
        self.cornerDegree = cornerDegree
        self.border = border
        self.shadow = shadow
        for child in children() {
            insert(child)
        }
    }
}

extension ShapeLayer {
    public convenience init(
        offset: SIMD3<Float> = .zero,
        size: SIMD2<Float> = .zero,
        shapes: [ShapeItem] = []
    ) {
        self.init()
        self.offset = offset
        self.size = size
        self.shapes = shapes
    }

    public convenience init(
        offset: SIMD3<Float> = .zero,
        size: SIMD2<Float> = .zero,
        @ShapeItemBuilder _ shapes: () -> [ShapeItem]
    ) {
        self.init()
        self.offset = offset
        self.size = size
        self.shapes = shapes()
    }
}

@resultBuilder
public struct ShapeItemBuilder {
    public static func buildBlock(_ items: ShapeItem...) -> [ShapeItem] { items }
    public static func buildArray(_ items: [[ShapeItem]]) -> [ShapeItem] { items.flatMap { $0 } }
    public static func buildOptional(_ items: [ShapeItem]?) -> [ShapeItem] { items ?? [] }
    public static func buildEither(first items: [ShapeItem]) -> [ShapeItem] { items }
    public static func buildEither(second items: [ShapeItem]) -> [ShapeItem] { items }
}
