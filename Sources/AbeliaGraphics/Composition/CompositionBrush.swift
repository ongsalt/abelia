public enum CompositionBrush {
  case solid(Color, blendMode: BlendMode = .normal)
  case texture(
    any CompositionTexture,
    fillMode: TextureFillMode = .stretch,
    crop: Rect = .unit,
    nineSlices: Rect = .unit
  )
  // mapped to Brush.texture
  // case gradient(Color) mapped to Brush.texture
}

public protocol CompositionTexture {
  var index: Int { get }
}

extension CompositionBrush {
  var brush: Brush {
    switch self {
    case .solid(let color, _):
      return Brush.solid(color)
    case .texture(let texture, let fillMode, let crop, let nineSlices):
      return Brush.texture(
        index: texture.index, fillMode: fillMode, crop: crop, nineSlices: nineSlices)
    }
  }
}

public enum BlendMode {
  case normal
  // case multiply
  // case hardLight
  // case difference
  case overlay
  // case lighten
  // case darknen
}
