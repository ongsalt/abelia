import Foundation

/// A `BinaryFloatingPoint` with the transcendental functions needed for closed-form
/// (analytic) motion solutions, e.g. the damped harmonic oscillator used by `SpringConfiguration`.
public protocol RealScalar: BinaryFloatingPoint {
    static func exp(_ x: Self) -> Self
    static func sin(_ x: Self) -> Self
    static func cos(_ x: Self) -> Self
}

extension Float: RealScalar {
    public static func exp(_ x: Float) -> Float { Foundation.exp(x) }
    public static func sin(_ x: Float) -> Float { Foundation.sin(x) }
    public static func cos(_ x: Float) -> Float { Foundation.cos(x) }
}

extension Double: RealScalar {
    public static func exp(_ x: Double) -> Double { Foundation.exp(x) }
    public static func sin(_ x: Double) -> Double { Foundation.sin(x) }
    public static func cos(_ x: Double) -> Double { Foundation.cos(x) }
}

/// A value the animation system can interpolate: it adds like a vector and scales by its own
/// `Scalar`. Scalars are `RealScalar` so solvers can run their closed-form math at the value's
public protocol VectorArithmetic {
    associatedtype Scalar: RealScalar

    static var zero: Self { get }
    static func + (lhs: Self, rhs: Self) -> Self
    static func - (lhs: Self, rhs: Self) -> Self
    static func * (lhs: Self, rhs: Scalar) -> Self
    static func * (lhs: Scalar, rhs: Self) -> Self

    /// Euclidean length, in the value's own units. Springs compare it against
    /// `SpringConfiguration.visibilityThreshold` to decide when the motion has settled.
    var length: Scalar { get }
}

extension Float: VectorArithmetic {
    public var length: Float { abs(self) }
}

extension Double: VectorArithmetic {
    public var length: Double { abs(self) }
}

extension SIMD where Scalar: RealScalar {
    @inline(__always)
    public var length: Scalar {
        (self * self).sum().squareRoot()
    }
}

extension SIMD2: VectorArithmetic where Scalar: RealScalar {}
extension SIMD3: VectorArithmetic where Scalar: RealScalar {}
extension SIMD4: VectorArithmetic where Scalar: RealScalar {}
