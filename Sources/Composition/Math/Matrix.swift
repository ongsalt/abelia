import Foundation

struct AffineMatrix {
    var c1: SIMD4<Float>
    var c2: SIMD4<Float>
    var c3: SIMD4<Float>
    var c4: SIMD4<Float>

    static var identity: AffineMatrix {
        AffineMatrix(
            c1: [1, 0, 0, 0],
            c2: [0, 1, 0, 0],
            c3: [0, 0, 1, 0],
            c4: [0, 0, 0, 1]
        )
    }

    static func * (lhs: AffineMatrix, rhs: AffineMatrix) -> AffineMatrix {
        func multiplyColumn(_ col: SIMD4<Float>) -> SIMD4<Float> {
            // Multiply each component of the rhs column by the corresponding lhs column
            return lhs.c1 * col.x + lhs.c2 * col.y + lhs.c3 * col.z + lhs.c4 * col.w
        }

        return AffineMatrix(
            c1: multiplyColumn(rhs.c1),
            c2: multiplyColumn(rhs.c2),
            c3: multiplyColumn(rhs.c3),
            c4: multiplyColumn(rhs.c4)
        )
    }

    static func * (m: AffineMatrix, v: SIMD4<Float>) -> SIMD4<Float> {
        return m.c1 * v.x + m.c2 * v.y + m.c3 * v.z + m.c4 * v.w
    }

    static func * (m: AffineMatrix, v: SIMD2<Float>) -> SIMD2<Float> {
        let result = m * SIMD4<Float>(v.x, v.y, 0, 1)
        return SIMD2<Float>(result.x, result.y)
    }

    // func fastInverse() -> AffineMatrix {
    //     // Transpose the 3x3 rotation part
    //     let r1 = SIMD3(c1.x, c2.x, c3.x)
    //     let r2 = SIMD3(c1.y, c2.y, c3.y)
    //     let r3 = SIMD3(c1.z, c2.z, c3.z)

    //     // New translation is -(R^T * old_translation)
    //     let oldT = SIMD3(c4.x, c4.y, c4.z)
    //     let newT = -(r1 * oldT.x + r2 * oldT.y + r3 * oldT.z)

    //     return AffineMatrix(
    //         c1: SIMD4(r1, 0),
    //         c2: SIMD4(r2, 0),
    //         c3: SIMD4(r3, 0),
    //         c4: SIMD4(newT, 1)
    //     )
    // }

    func then(_ other: AffineMatrix) -> AffineMatrix {
        other * self
    }
 
    func inverse() -> AffineMatrix {
        let val0 = c1.x * c2.y - c1.y * c2.x
        let val1 = c1.x * c2.z - c1.z * c2.x
        let val2 = c1.x * c2.w - c1.w * c2.x
        let val3 = c1.y * c2.z - c1.z * c2.y
        let val4 = c1.y * c2.w - c1.w * c2.y
        let val5 = c1.z * c2.w - c1.w * c2.z
        let val6 = c3.x * c4.y - c3.y * c4.x
        let val7 = c3.x * c4.z - c3.z * c4.x
        let val8 = c3.x * c4.w - c3.w * c4.x
        let val9 = c3.y * c4.z - c3.z * c4.y
        let val10 = c3.y * c4.w - c3.w * c4.y
        let val11 = c3.z * c4.w - c3.w * c4.z

        let det =
            val0 * val11 - val1 * val10 + val2 * val9 + val3 * val8 - val4 * val7 + val5 * val6
        let invDet = 1.0 / det

        return AffineMatrix(
            c1: SIMD4(
                (c2.y * val11 - c2.z * val10 + c2.w * val9) * invDet,
                -(c1.y * val11 - c1.z * val10 + c1.w * val9) * invDet,
                (c4.y * val5 - c4.z * val4 + c4.w * val3) * invDet,
                -(c3.y * val5 - c3.z * val4 + c3.w * val3) * invDet
            ),
            c2: SIMD4(
                -(c2.x * val11 - c2.z * val8 + c2.w * val7) * invDet,
                (c1.x * val11 - c1.z * val8 + c1.w * val7) * invDet,
                -(c4.x * val5 - c4.z * val2 + c4.w * val1) * invDet,
                (c3.x * val5 - c3.z * val2 + c3.w * val1) * invDet
            ),
            c3: SIMD4(
                (c2.x * val10 - c2.y * val8 + c2.w * val6) * invDet,
                -(c1.x * val10 - c1.y * val8 + c1.w * val6) * invDet,
                (c4.x * val4 - c4.y * val2 + c4.w * val0) * invDet,
                -(c3.x * val4 - c3.y * val2 + c3.w * val0) * invDet
            ),
            c4: SIMD4(
                -(c2.x * val9 - c2.y * val7 + c2.z * val6) * invDet,
                (c1.x * val9 - c1.y * val7 + c1.z * val6) * invDet,
                -(c4.x * val3 - c4.y * val1 + c4.z * val0) * invDet,
                (c3.x * val3 - c3.y * val1 + c3.z * val0) * invDet
            )
        )
    }

    mutating func translate(x: Float, y: Float, z: Float) {
        c4 = c1 * x + c2 * y + c3 * z + c4
    }

    // Scale: Multiplies basis vectors by scalars
    mutating func scale(x: Float, y: Float, z: Float) {
        c1 *= x
        c2 *= y
        c3 *= z
    }

    // Rotate: Rotates around a normalized axis using Rodrigues' rotation formula logic
    mutating func rotate(angleRadians: Float, axis: SIMD3<Float>) {
        let c = cos(angleRadians)
        let s = sin(angleRadians)
        let mc = 1 - c

        let r = AffineMatrix(
            c1: [
                c + axis.x * axis.x * mc, axis.y * axis.x * mc + axis.z * s,
                axis.z * axis.x * mc - axis.y * s, 0,
            ],
            c2: [
                axis.x * axis.y * mc - axis.z * s, c + axis.y * axis.y * mc,
                axis.z * axis.y * mc + axis.x * s, 0,
            ],
            c3: [
                axis.x * axis.z * mc + axis.y * s, axis.y * axis.z * mc - axis.x * s,
                c + axis.z * axis.z * mc, 0,
            ],
            c4: [0, 0, 0, 1]
        )
        self = self * r
    }

    // Flip: Simple reflection by negating an axis (e.g., y: -1 for Vulkan/Screen space swap)
    mutating func flip(x: Bool, y: Bool, z: Bool) {
        if x { c1 = -c1 }
        if y { c2 = -c2 }
        if z { c3 = -c3 }
    }
}

extension AffineMatrix {
    func translated(x: Float, y: Float, z: Float) -> AffineMatrix {
        var result = self
        result.translate(x: x, y: y, z: z)
        return result
    }

    func scaled(x: Float, y: Float, z: Float) -> AffineMatrix {
        var result = self
        result.scale(x: x, y: y, z: z)
        return result
    }

    func rotated(angleRadians: Float, axis: SIMD3<Float>) -> AffineMatrix {
        var result = self
        result.rotate(angleRadians: angleRadians, axis: axis)
        return result
    }

    func flipped(x: Bool, y: Bool, z: Bool) -> AffineMatrix {
        var result = self
        result.flip(x: x, y: y, z: z)
        return result
    }
}
