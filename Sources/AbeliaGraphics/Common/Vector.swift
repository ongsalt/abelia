import Foundation

public protocol VectorArithmetic: AdditiveArithmetic & Comparable & SignedNumeric where Magnitude == Scalar {
    associatedtype Scalar: BinaryFloatingPoint
    static func * (lhs: Self, rhs: Scalar) -> Self
    static func * (lhs: Scalar, rhs: Self) -> Self
}

extension Float: VectorArithmetic {
    public typealias Scalar = Float
}

extension Double: VectorArithmetic {
    public typealias Scalar = Double
}

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

public struct Vec2<Scalar: BinaryFloatingPoint & Sendable>: Sendable {
    public var x: Scalar
    public var y: Scalar

    public init(_ x: Scalar, _ y: Scalar) {
        self.x = x
        self.y = y
    }

    public init(repeating value: Scalar) {
        self.x = value
        self.y = value
    }
}

extension Vec2: AdditiveArithmetic {
    public static var zero: Vec2 { Vec2(0, 0) }

    public static func + (lhs: Vec2, rhs: Vec2) -> Vec2 {
        Vec2(lhs.x + rhs.x, lhs.y + rhs.y)
    }

    public static func - (lhs: Vec2, rhs: Vec2) -> Vec2 {
        Vec2(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}

extension Vec2: Numeric {
    public typealias Magnitude = Scalar

    public init?<T: BinaryInteger>(exactly source: T) {
        guard let value = Scalar(exactly: source) else { return nil }
        self.init(repeating: value)
    }

    public var magnitude: Scalar {
        (x * x + y * y).squareRoot()
    }

    public static func * (lhs: Vec2, rhs: Vec2) -> Vec2 {
        Vec2(lhs.x * rhs.x, lhs.y * rhs.y)
    }

    public static func *= (lhs: inout Vec2, rhs: Vec2) {
        lhs = lhs * rhs
    }
}

extension Vec2: SignedNumeric {}

extension Vec2: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(repeating: Scalar(value))
    }
}

extension Vec2: Comparable {
    public static func < (lhs: Vec2, rhs: Vec2) -> Bool {
        lhs.magnitude < rhs.magnitude
    }
}

extension Vec2: VectorArithmetic {
    public static func * (lhs: Vec2, rhs: Scalar) -> Vec2 {
        Vec2(lhs.x * rhs, lhs.y * rhs)
    }

    public static func * (lhs: Scalar, rhs: Vec2) -> Vec2 {
        Vec2(lhs * rhs.x, lhs * rhs.y)
    }
}

extension Vec2 where Scalar: SIMDScalar {
    public init(_ simd: SIMD2<Scalar>) {
        self.init(simd.x, simd.y)
    }

    public var simd: SIMD2<Scalar> {
        SIMD2(x, y)
    }
}

public struct Vec3<Scalar: BinaryFloatingPoint & Sendable>: Sendable {
    public var x: Scalar
    public var y: Scalar
    public var z: Scalar

    public init(_ x: Scalar, _ y: Scalar, _ z: Scalar) {
        self.x = x
        self.y = y
        self.z = z
    }

    public init(repeating value: Scalar) {
        self.x = value
        self.y = value
        self.z = value
    }
}

extension Vec3: AdditiveArithmetic {
    public static var zero: Vec3 { Vec3(0, 0, 0) }

    public static func + (lhs: Vec3, rhs: Vec3) -> Vec3 {
        Vec3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }

    public static func - (lhs: Vec3, rhs: Vec3) -> Vec3 {
        Vec3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }
}

extension Vec3: Numeric {
    public typealias Magnitude = Scalar

    public init?<T: BinaryInteger>(exactly source: T) {
        guard let value = Scalar(exactly: source) else { return nil }
        self.init(repeating: value)
    }

    public var magnitude: Scalar {
        (x * x + y * y + z * z).squareRoot()
    }

    public static func * (lhs: Vec3, rhs: Vec3) -> Vec3 {
        Vec3(lhs.x * rhs.x, lhs.y * rhs.y, lhs.z * rhs.z)
    }

    public static func *= (lhs: inout Vec3, rhs: Vec3) {
        lhs = lhs * rhs
    }
}

extension Vec3: SignedNumeric {}

extension Vec3: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(repeating: Scalar(value))
    }
}

extension Vec3: Comparable {
    public static func < (lhs: Vec3, rhs: Vec3) -> Bool {
        lhs.magnitude < rhs.magnitude
    }
}

extension Vec3: VectorArithmetic {
    public static func * (lhs: Vec3, rhs: Scalar) -> Vec3 {
        Vec3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    public static func * (lhs: Scalar, rhs: Vec3) -> Vec3 {
        Vec3(lhs * rhs.x, lhs * rhs.y, lhs * rhs.z)
    }
}

extension Vec3 where Scalar: SIMDScalar {
    public init(_ simd: SIMD3<Scalar>) {
        self.init(simd.x, simd.y, simd.z)
    }

    public var simd: SIMD3<Scalar> {
        SIMD3(x, y, z)
    }
}
