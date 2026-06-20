public enum Brush {
  case solid(Color)
  /// nineSlices and crop are normalized
  case texture(
    _ texture: any RenderTextureProtocol, 
    fillMode: TextureFillMode = .stretch, 
    crop: Rect = .unit,
    nineSlices: Rect = .unit
  )
  // case effect
}

public enum TextureFillMode {
  case stretch
  case tile(scale: SIMD2<Float> = .one, offset: SIMD2<Float> = .zero)
}
