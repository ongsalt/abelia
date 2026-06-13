import CShim

extension RenderNode {
  func write(to data: inout CShim.RenderNode, identity: ObjectIdentifier, shapeGroupStorage: borrowing ShapeGroupStorage) {
    // zero it
    data = CShim.RenderNode()

    data.affine = self.nodeTotalAffine.c
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
      let startIndex = shapeGroupStorage.update(ownerIdentity: identity, data: instructions)
      data.shapeData.many = CShim.ManyShapeRef(startIndex: UInt32(startIndex!), count: UInt32(instructions.count))
      // shapeGroupStorage.print(offset: startIndex!, count: instructions.count)
    }

    switch brush {
    case .solid(let color):
      data.brushKind = BrushKind.solid
      let (r, g, b, a) = color.values
      data.brushData.solid = CShim.SolidColorBrush(color: (r, g, b, a))
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
      shape.arc = CShim.Arc(radius: radius, angle: angle, thickness: thickness)
    case .pie(let radius, let angle, let perimeterOffset):
      shapeKind = ShapeKind.pie
      shape.pie = CShim.Pie(
        radius: radius, angle: angle, perimeterOffset: perimeterOffset)
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
