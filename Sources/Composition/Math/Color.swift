// TODO: oklch color
struct OklchColor {
    let l: Float
    let c: Float
    let h: Float
    let a: Float
}

struct Color {
    let r: Float
    let g: Float
    let b: Float
    let a: Float

    init(
        _ r: Float,
        _ g: Float,
        _ b: Float,
        _ a: Float
    ) {
        self.a = a
        self.r = r
        self.g = g
        self.b = b
    }

    init(
        r: Float,
        g: Float,
        b: Float,
        a: Float
    ) {
        self = .init(r, g, b, a)
    }

    init(rgb: UInt32) {
        self.r = Float((rgb >> 16) & 0xFF) / 255.0
        self.g = Float((rgb >> 8) & 0xFF) / 255.0
        self.b = Float((rgb >> 0) & 0xFF) / 255.0
        self.a = 1.0
    }

    init(rgba: UInt32) {
        self.r = Float((rgba >> 24) & 0xFF) / 255.0
        self.g = Float((rgba >> 16) & 0xFF) / 255.0
        self.b = Float((rgba >> 8) & 0xFF) / 255.0
        self.a = Float(rgba & 0xFF) / 255.0
    }

    func toUInt8() -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        (
            r: UInt8(r.clamp(0, 1) * 255),
            g: UInt8(g.clamp(0, 1) * 255),
            b: UInt8(b.clamp(0, 1) * 255),
            a: UInt8(a.clamp(0, 1) * 255)
        )
    }

    func toARGB8888() -> UInt32 {
        let (r, g, b, a) = toUInt8()
        return (UInt32(g) << (1 * 8))  // 0x3400
            | (UInt32(b) << (0 * 8))  // 0x560000
            | (UInt32(r) << (2 * 8))  // 0x12
            | (UInt32(a) << (3 * 8))  // 0x78000000
    }

    // shitty alpha blending
    func lerp(over other: Color, progress p: Float) -> Color {
        // return s.lerp(over: other)

        let effectiveOpacity = self.a * p

        return Color(
            r: (r * effectiveOpacity + other.r * other.a * (1 - effectiveOpacity)),
            g: (g * effectiveOpacity + other.g * other.a * (1 - effectiveOpacity)),
            b: (b * effectiveOpacity + other.b * other.a * (1 - effectiveOpacity)),
            a: other.a + (1 - other.a) * effectiveOpacity
        )

    }

    func lerp(over other: Color) -> Color {
        // 0.6 + 0.6 != 1.2
        // its 1 - 0.16 = 0.84
        // a $ b = a + (1 - a)b
        let ia = 1 - a
        let outputA = ia * other.a + a
        return Color(
            r: (r * a + ia * other.r * other.a) / outputA,
            g: (g * a + ia * other.g * other.a) / outputA,
            b: (b * a + ia * other.b * other.a) / outputA,
            a: outputA
        )
    }

    func mutiply(over other: Color) -> Color {
        other.mutiply(self)
    }

    func mutiply(_ other: Color) -> Color {
        Color(
            r: r * other.r,
            g: g * other.g,
            b: b * other.b,
            a: a * other.a
        )
    }

    func multiply(scalar mutiplier: Float) -> Color {
        Color(r: mutiplier * r, g: mutiplier * g, b: mutiplier * b, a: a)
    }

    func multiply(opacity: Float) -> Color {
        Color(r: r, g: g, b: b, a: a * opacity)
    }

    func premulitplied() -> Color {
        Color(r: r * a, g: g * a, b: b * a, a: a)
    }

    func screen(_ other: Color) -> Color {
        Color(
            r: 1 - (1 - r) * (1 - other.r),
            g: 1 - (1 - g) * (1 - other.g),
            b: 1 - (1 - b) * (1 - other.b),
            a: 1 - (1 - a) * (1 - other.a)
        )
    }

    func overlay(over other: Color) -> Color {
        other.overlay(self)
    }

    func overlay(_ other: Color) -> Color {
        Color(
            r: r < 0.5 ? 2 * r * other.r : 1 - 2 * (1 - r) * (1 - other.r),
            g: g < 0.5 ? 2 * g * other.g : 1 - 2 * (1 - g) * (1 - other.g),
            b: b < 0.5 ? 2 * b * other.b : 1 - 2 * (1 - b) * (1 - other.b),
            // a: a < 0.5 ? 2 * a * other.a : 1 - 2 * (1 - a) * (1 - other.a)
            a: 1
        )
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        Color(r: lhs.r + rhs.r, g: lhs.g + rhs.g, b: lhs.b + rhs.b, a: max(lhs.a, rhs.a))
    }

    static func random(alpha: Float) -> Color {
        Color(Float.random(in: 0...1), .random(in: 0...1), .random(in: 0...1), alpha)
    }
}


