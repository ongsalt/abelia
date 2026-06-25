import AbeliaGraphics

func idk() {
    let root = Layer(offset: [100, 0, 0], size: [700, 700], brush: .solid(.blue)) {
        Layer(
            size: [500, 500],
            brush: .solid(.red.with(alpha: 0.5))
        )
        EffectLayer(
            offset: [100, 100, 0],
            shape: Shape.rect(width: 500, height: 500, cornerRadius: 100),
            effect: .blur(radius: 50),
            // .refraction(amount: 10, height: 10),
            // ]
        )
        Layer(
            offset: [200, 200, 0],
            size: [500, 500],
            brush: .solid(.green.with(alpha: 0.5))
        )
    }
}

func nonOverlapBlurGrid(w: Int, h: Int, size: Float = 10) {
    let root = Layer(size: SIMD2(Float(w) * size, Float(h) * size))

    for x in 0..<w {
        for y in 0..<h {
            root.insert(
                EffectLayer(
                    offset: SIMD3(Float(x) * size, Float(y) * size, 0),
                    shape: Shape.rect(width: size, height: size, cornerRadius: 10),
                    effect: .blur(radius: 20)
                )
            )
        }
    }
}
