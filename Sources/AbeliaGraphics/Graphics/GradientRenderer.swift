class GradientRenderer {

  // func get() -> GPUTask<GradientTexture> {
  //   fatalError("unimplemented")
  // }
}

struct GradientTexture {
  let texture: RenderTexture
  // let dimension  
}

public func gradient(@ColorStopBuilder<Float> builder: () -> [ColorStop<Float>]) -> [ColorStop<
  Float
>] {
  builder()
}

public func asd() {
  let stops = gradient {
    Color.red.at(0.0)
  }
}

@resultBuilder
public struct ColorStopBuilder<Position> {
  public typealias Component = ColorStop<Position>
  public static func buildBlock(_ stops: Component...) -> [Component] { stops }
  public static func buildArray(_ stops: [[Component]]) -> [Component] { stops.flatMap { $0 } }
  public static func buildOptional(_ stops: [Component]?) -> [Component] { stops ?? [] }
  public static func buildEither(first stops: [Component]) -> [Component] { stops }
  public static func buildEither(second stops: [Component]) -> [Component] { stops }
}

public struct ColorStop<Position> {
  public var color: Color
  public var position: Position

  public init(_ color: Color, at position: Position) {
    self.color = color
    self.position = position
  }
}

extension Color {
  func at(_ position: Float) -> ColorStop<Float> {
    ColorStop(self, at: position)
  }

  func at(_ position: SIMD2<Float>) -> ColorStop<SIMD2<Float>> {
    ColorStop(self, at: position)
  }
}
