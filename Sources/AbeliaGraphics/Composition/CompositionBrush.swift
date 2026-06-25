public enum CompositionBrush {
  case solid(Color, blendMode: BlendMode = .normal)
  // case texture(Texture, crop, ninegrid) mapped to Brush.texture
  // case gradient(Color) mapped to Brush.texture
}

extension CompositionBrush {
  var brush: Brush {
    switch self {
    case .solid(let color, _):
      return Brush.solid(color)
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
