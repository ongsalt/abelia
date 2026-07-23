public enum CompositionBrush: Equatable {
  case solid(Color, blendMode: BlendMode = .normal)
  case texture(
    any CompositionTexture,
    fillMode: TextureFillMode = .stretch,
    crop: Rect = .unit,
    nineSlices: Rect = .unit
  )

  // case effect(any CompositionEffect)
  // mapped to Brush.texture
  // case gradient(Color) mapped to Brush.texture

  public static func == (lhs: CompositionBrush, rhs: CompositionBrush) -> Bool {
    switch (lhs, rhs) {
    case let (.solid(lhsColor, lhsBlendMode), .solid(rhsColor, rhsBlendMode)):
      return lhsColor == rhsColor && lhsBlendMode == rhsBlendMode
    case let (
      .texture(lhsTexture, lhsFillMode, lhsCrop, lhsNineSlices),
      .texture(rhsTexture, rhsFillMode, rhsCrop, rhsNineSlices)
    ):
      return lhsTexture.index == rhsTexture.index
        && lhsFillMode == rhsFillMode
        && lhsCrop == rhsCrop
        && lhsNineSlices == rhsNineSlices
    default:
      return false
    }
  }
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

public class CompositionImage: CompositionTexture, Equatable {
    public var index: Int {
        texture.index
    }
    let texture: RenderTexture

    init(_ texture: RenderTexture) {
        self.texture = texture
    }

    public static func == (lhs: CompositionImage, rhs: CompositionImage) -> Bool {
        lhs === rhs
    }
}

