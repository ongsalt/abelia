import CShim

extension RenderNode {
  func write(
    to data: inout CShim.RenderNode, identity: ObjectIdentifier,
    shapeGroupStorage: borrowing ShapeGroupStorage
  ) {
    // zero it
    data = CShim.RenderNode()

    data.affine = self.affine.c
    let instructions = Array(shape.drawInstructions)
    if instructions.count <= 1 {
      guard case .push(let metadata) = instructions[0] else {
        fatalError("Invalid shape merging instruction: \(instructions)")
      }

      let (kind, shapeData) = metadata.shape.c
      data.oneOrManyKind = .one_shape
      data.shapeKind = kind
      data.shapeData.one = shapeData
    } else {
      data.oneOrManyKind = .many_shapes
      // let startIndex = shapeGroupStorage.update(ownerIdentity: identity, data: instructions)
      // data.shapeData.many = CShim.ManyShapeRef(
      //   startIndex: UInt32(startIndex!), count: UInt32(instructions.count))
    }

    // this can be cache
    let bounds = shape.bounds
    data.boundMinX = bounds.left - (borderWidth + 2)
    data.boundMinY = bounds.top - (borderWidth + 2)
    data.boundMaxX = bounds.right + borderWidth + 2
    data.boundMaxY = bounds.bottom + borderWidth + 2

    switch brush {
    case .solid(let color):
      data.brushKind = .solid
      let (r, g, b, a) = color.linearized.premultiplied.values
      data.brushData.solid = CShim.SolidColorBrush(color: (r, g, b, a))
    case .texture(let index, let fillMode, let crop, let nineSlices):
      data.brushKind = .texture
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

      data.brushData.texture = CShim.TextureBrush(
        textureIndex: UInt32(index),  // resolved externally when binding textures
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
    }

    data.borderWidth = self.borderWidth
    data.shadowOffsetX = self.shadowOffset.x
    data.shadowOffsetY = self.shadowOffset.y
    data.shadowBlur = self.shadowBlur
    data.shadowSpread = self.shadowSpread
    data.shadowOpacity = self.shadowOpacity
    let (sr, sg, sb, sa) = shadowColor.linearized.premultiplied.values
    data.shadowColorR = sr
    data.shadowColorG = sg
    data.shadowColorB = sb
    data.shadowColorA = sa

    switch borderBrush {
    case .solid(let color):
      data.borderBrushKind = .solid
      let (r, g, b, a) = color.linearized.premultiplied.values
      data.borderBrushData.solid = CShim.SolidColorBrush(color: (r, g, b, a))
    case .texture(let index, let fillMode, let crop, let nineSlices):
      data.borderBrushKind = .texture
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

      data.borderBrushData.texture = CShim.TextureBrush(
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
    }

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
