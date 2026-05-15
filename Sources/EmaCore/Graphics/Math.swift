import CVulkan

public typealias Vec2d<T: SIMDScalar> = SIMD2<T>
public typealias Vec3d<T: SIMDScalar> = SIMD2<T>

public typealias Size<T: SIMDScalar> = Vec2d<T>
public typealias Position<T: SIMDScalar> = Vec2d<T>

extension SIMD2 where Scalar: BinaryInteger {
  var asExtent: VkExtent2D {
    VkExtent2D(width: UInt32(x), height: UInt32(y))
  }
}

public struct AffineMatrix {
  var c1: SIMD4<Float>
  var c2: SIMD4<Float>
  var c3: SIMD4<Float>
  var c4: SIMD4<Float>
}
