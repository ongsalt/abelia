public enum Brush: Sendable {
  case solid(Color)
  /// nineSlices and crop are normalized
  case texture(
    index: Int, 
    fillMode: TextureFillMode = .stretch, 
    crop: Rect = .unit,
    nineSlices: Rect = .unit
  )

  // do not exist in c
  case backdrop(
    key: Int, 
    crop: Rect = .unit,
  )
}

public enum TextureFillMode: Sendable {
  case stretch
  case tile(scale: SIMD2<Float> = .one, offset: SIMD2<Float> = .zero)
  case absolute
}
