import CShim

extension Brush {
  var c: (CShim.BrushKind, CShim.Brush) {
    var data = CShim.Brush()
    var kind = CShim.BrushKind.solid
    switch self {
    case .solid(let color):
      kind = .solid
      let (r, g, b, a) = color.linearized.premultiplied.values
      data.solid = CShim.SolidColorBrush(color: (r, g, b, a))
    case .texture(let index, let fillMode, let crop, let nineSlices):
      kind = .texture
      let fillModeRaw: UInt32
      let tileScaleX: Float
      let tileScaleY: Float
      switch fillMode {
      case .stretch:
        fillModeRaw = 0
        tileScaleX = 1
        tileScaleY = 1
      case .tile(let s, _):
        fillModeRaw = 1
        tileScaleX = s.x
        tileScaleY = s.y
      case .absolute:
        fillModeRaw = 2
        tileScaleX = 1
        tileScaleY = 1
      }

      data.texture = CShim.TextureBrush(
        textureIndex: UInt32(index),
        fillMode: fillModeRaw,
        tileScaleX: tileScaleX,
        tileScaleY: tileScaleY,
        cropLeft: crop.left,
        cropTop: crop.top,
        cropWidth: crop.width,
        cropHeight: crop.height,
        sliceLeft: nineSlices.left,
        sliceTop: nineSlices.top,
        sliceWidth: nineSlices.width,
        sliceHeight: nineSlices.height,
        sizeX: 0,
        sizeY: 0
      )
    case .backdrop(_, _):
      kind = .texture
      fatalError(".backdrop must be resolve before converting to c")
    }

    return (kind, data)
  }

}

extension Shape {
  public var c: (CShim.ShapeKind, CShim.Shape) {
    var shapeKind: CShim.ShapeKind = .rect
    var shape = CShim.Shape()

    switch self {
    case .rect(let width, let height, let cornerRadius, let cornerDegree):
      shapeKind = ShapeKind.rect
      // shapeKind = 0
      shape.rect = CShim.Rect(
        width: width, height: height, cornerRadius: cornerRadius, cornerDegree: cornerDegree
      )
    case .arc(let radius, let angle, let thickness):
      shapeKind = ShapeKind.arc
      shape.arc = CShim.Arc(radius: radius, angle: angle.radians, thickness: thickness)
    case .pie(let radius, let angle, let perimeterOffset):
      shapeKind = ShapeKind.pie
      shape.pie = CShim.Pie(
        radius: radius, angle: angle.radians, perimeterOffset: perimeterOffset)
    case .ellipse(let radiusX, let radiusY):
      shapeKind = ShapeKind.ellipse
      shape.ellipse = CShim.Ellipse(radiusX: radiusX, radiusY: radiusY)
    }

    return (shapeKind, shape)
  }
}

extension Affine {
  var c:
    (
      Float, Float, Float, Float,
      Float, Float, Float, Float,
      Float, Float, Float, Float,
      Float, Float, Float, Float,
    )
  {
    (
      col0.x, col0.y, col0.z, col0.w,
      col1.x, col1.y, col1.z, col1.w,
      col2.x, col2.y, col2.z, col2.w,
      col3.x, col3.y, col3.z, col3.w
    )
  }
}

extension ShapeMergingInstruction {
  var c: CShim.ShapeMergingEntry {
    var entry = CShim.ShapeMergingEntry()
    switch self {
    case .merge(let mode, let smoothing):
      entry.kind = .merge
      entry.data.merge = CShim.MergeNode(
        mode: CShim.MergeMode(rawValue: mode.rawValue)!,
        // smoothing: max(smoothing, Float.leastNonzeroMagnitude)
        smoothing: smoothing
      )
    case .push(let metadata):
      let (kind, shapeData) = metadata.shape.c
      entry.kind = .push
      entry.data.shape = CShim.ShapeMetadata(
        shapeKind: kind,
        shape: shapeData,
        offset: (metadata.offset.x, metadata.offset.y)
      )
    }
    return entry
  }
}
