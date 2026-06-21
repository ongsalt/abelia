import Vulkan

class GradientRenderer {

  func get() -> GPUTask<RenderTexture> {
    fatalError("unimplemented")
  }
}

// TODO: 2d gradient, we have to think abuot bezier control point
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

struct GradientPipeline {
  init(context: DeviceContext) throws {
    let format: Format = .r16g16b16a16Unorm
    guard let shaderModule = context.device.createShaderModule(filename: "gradient") else {
      fatalError("cannot load gradient shader")
    }

    let layout = try context.device.createPipelineLayout(
      PipelineLayoutCreateInfo(
        setLayouts: [],
        pushConstantRanges: [
          PushConstantRange(
            stageFlags: [.fragment, .vertex], offset: 0,
            size: UInt32(MemoryLayout<(UInt32, UInt32)>.size)
          )
        ]
      ))
  }
}
