struct LayoutBox {

}

struct Constraints {
    let minWidth: Float
    let maxWidth: Float
    let minHeight: Float
    let maxHeight: Float

    static let zero = Constraints(minWidth: 0, maxWidth: 0, minHeight: 0, maxHeight: 0)
}

extension Constraints {
    init(
        minSize: SIMD2<Float>,
        maxSize: SIMD2<Float>
    ) {
        self.init(
            minWidth: minSize.x, maxWidth: maxSize.x, minHeight: minSize.y, maxHeight: maxSize.y)
    }

    init(
        size: SIMD2<Float>,
    ) {
        self.init(
            minSize: size,
            maxSize: size
        )
    }

}

extension Constraints {
    var minSize: SIMD2<Float> {
        SIMD2(minWidth, minHeight)
    }

    var maxSize: SIMD2<Float> {
        SIMD2(maxWidth, maxHeight)
    }

    func clamp(_ size: SIMD2<Float>) -> SIMD2<Float> {
        size.clamped(lowerBound: minSize, upperBound: maxSize)
    }
}
