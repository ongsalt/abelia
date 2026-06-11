import Foundation

public struct Affine: Sendable {
    // Column-major representation using standard library cross-platform SIMD types
    public var col0: SIMD4<Float>
    public var col1: SIMD4<Float>
    public var col2: SIMD4<Float>
    public var col3: SIMD4<Float>

    public static let identity = Affine(
        col0: SIMD4<Float>(1, 0, 0, 0),
        col1: SIMD4<Float>(0, 1, 0, 0),
        col2: SIMD4<Float>(0, 0, 1, 0),
        col3: SIMD4<Float>(0, 0, 0, 1)
    )

    public init(col0: SIMD4<Float>, col1: SIMD4<Float>, col2: SIMD4<Float>, col3: SIMD4<Float>) {
        self.col0 = col0
        self.col1 = col1
        self.col2 = col2
        self.col3 = col3
    }

    // MARK: - Core Multiplication
    
    // Helper to multiply the matrix by a single column vector
    @inline(__always)
    private func multiplyVector(_ v: SIMD4<Float>) -> SIMD4<Float> {
        return (v.x * col0) + (v.y * col1) + (v.z * col2) + (v.w * col3)
    }

    public func multiplied(by other: Affine) -> Affine {
        return Affine(
            col0: multiplyVector(other.col0),
            col1: multiplyVector(other.col1),
            col2: multiplyVector(other.col2),
            col3: multiplyVector(other.col3)
        )
    }

    // MARK: - Chaining Methods (Returns new Affine)

    public func scaled(x: Float, y: Float, z: Float = 1.0) -> Affine {
        let scaleMatrix = Affine(
            col0: SIMD4<Float>(x, 0, 0, 0),
            col1: SIMD4<Float>(0, y, 0, 0),
            col2: SIMD4<Float>(0, 0, z, 0),
            col3: SIMD4<Float>(0, 0, 0, 1)
        )
        return self.multiplied(by: scaleMatrix)
    }

    public func translated(x: Float, y: Float, z: Float = 0.0) -> Affine {
        let translationMatrix = Affine(
            col0: SIMD4<Float>(1, 0, 0, 0),
            col1: SIMD4<Float>(0, 1, 0, 0),
            col2: SIMD4<Float>(0, 0, 1, 0),
            col3: SIMD4<Float>(x, y, z, 1)
        )
        return self.multiplied(by: translationMatrix)
    }

    public func rotated(radians: Float, axis: SIMD3<Float> = SIMD3<Float>(0, 0, 1)) -> Affine {
        // Manual axis-angle rotation matrix (since simd_quatf isn't available)
        let length = sqrt(axis.x * axis.x + axis.y * axis.y + axis.z * axis.z)
        let n = axis / length
        
        let c = cos(radians)
        let s = sin(radians)
        let t = 1.0 - c
        
        let x = n.x, y = n.y, z = n.z
        
        let rotationMatrix = Affine(
            col0: SIMD4<Float>(t*x*x + c,   t*x*y + s*z, t*x*z - s*y, 0),
            col1: SIMD4<Float>(t*x*y - s*z, t*y*y + c,   t*y*z + s*x, 0),
            col2: SIMD4<Float>(t*x*z + s*y, t*y*z - s*x, t*z*z + c,   0),
            col3: SIMD4<Float>(0,           0,           0,           1)
        )
        return self.multiplied(by: rotationMatrix)
    }

    // MARK: - Mutating Methods (Modifies in place)

    public mutating func scale(x: Float, y: Float, z: Float = 1.0) {
        self = self.scaled(x: x, y: y, z: z)
    }

    public mutating func translate(x: Float, y: Float, z: Float = 0.0) {
        self = self.translated(x: x, y: y, z: z)
    }

    public mutating func rotate(radians: Float, axis: SIMD3<Float> = SIMD3<Float>(0, 0, 1)) {
        self = self.rotated(radians: radians, axis: axis)
    }
}
