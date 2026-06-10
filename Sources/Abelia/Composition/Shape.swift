public typealias ShapeWithOffset = (Shape, SIMD2<Float>)

public protocol ShapeProtocol {
  associatedtype Shapes: Sequence where Shapes.Element == ShapeWithOffset
  var shapes: Shapes { get }
}

/// perimeterOffset just directly subtract the distance, effectively moving isoperimeter out and rounding it 
public enum Shape {
  case rect(width: Float, height: Float, cornerRadius: Float = 0, cornerDegree: Float = 4)
  case arc(radius: Float, angle: Float, thickness: Float)
  case pie(radius: Float, angle: Float, perimeterOffset: Float = 0)
  /// 0, 0 is the center
  // case polygon(_ vertices: [SIMD2<Float>], perimeterOffset: Float = 0)
  case ellipse(radiusX: Float, radiusY: Float)
}

extension Shape {
  public static func circle(_ radius: Float) -> Self {
    .ellipse(radiusX: radius, radiusY: radius)
  }
}

extension Shape: ShapeProtocol {
  public var shapes: some Sequence<ShapeWithOffset> { CollectionOfOne((self, .zero)) }
}

public struct MergedShape<First: ShapeProtocol, Second: ShapeProtocol> {
  let mode: MergeMode
  let smoothing: Float
  let first: First
  let second: Second
  let secondOffset: SIMD2<Float>
}

extension MergedShape: ShapeProtocol {
  public var shapes: some Sequence<ShapeWithOffset> {
    let offset = secondOffset
    return SequenceChain(first.shapes, second.shapes.lazy.map { ($0.0, $0.1 + offset) })
  }
}

public enum MergeMode: UInt32 {
  case union = 0
  case intersect = 1
  case xor = 2
  case subtract = 3
}

extension ShapeProtocol {
  func union<Other: ShapeProtocol>(
    _ other: Other, offset: SIMD2<Float> = .zero, smoothing: Float = 0
  )
    -> MergedShape<Self, Other>
  {
    MergedShape(
      mode: .union, smoothing: smoothing, first: self, second: other, secondOffset: offset)
  }

  func intersect<Other: ShapeProtocol>(
    _ other: Other, offset: SIMD2<Float> = .zero, smoothing: Float = 0
  )
    -> MergedShape<Self, Other>
  {
    MergedShape(
      mode: .intersect, smoothing: smoothing, first: self, second: other, secondOffset: offset)
  }

  func subtract<Other: ShapeProtocol>(
    _ other: Other, offset: SIMD2<Float> = .zero, smoothing: Float = 0
  )
    -> MergedShape<Self, Other>
  {
    MergedShape(
      mode: .subtract, smoothing: smoothing, first: self, second: other, secondOffset: offset)
  }

  func xor<Other: ShapeProtocol>(_ other: Other, offset: SIMD2<Float> = .zero, smoothing: Float = 0)
    -> MergedShape<Self, Other>
  {
    MergedShape(
      mode: .xor, smoothing: smoothing, first: self, second: other, secondOffset: offset)
  }
}

private func shit() {
  let merged = Shape.rect(width: 100, height: 100)
    .union(Shape.circle(23), offset: [0, 25])
    .union(Shape.circle(23), offset: [100, 0])

  for (shape, offset) in merged.shapes {
    print(shape, offset)
  }
}
