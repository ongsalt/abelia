public struct ShapeMetadata: Sendable {
  public var shape: Shape
  public var offset: SIMD2<Float>

  public init(_ shape: Shape, _ offset: SIMD2<Float>) {
    self.shape = shape
    self.offset = offset
  }
}

// postfix notation
public enum ShapeMergingInstruction {
  case merge(MergeMode)
  case push(ShapeMetadata)
}

public protocol ShapeProtocol: Sendable {
  associatedtype DrawInstructions: Sequence<ShapeMergingInstruction>
  var drawInstructions: DrawInstructions { get }
}

/// perimeterOffset just directly subtract the distance, effectively moving isoperimeter out and rounding it
public enum Shape: Sendable {
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
  @inlinable
  public var drawInstructions: some Sequence<ShapeMergingInstruction> {
    CollectionOfOne(.push(ShapeMetadata(self, .zero)))
  }
}

public struct MergedShape<First: ShapeProtocol, Second: ShapeProtocol>: Sendable {
  @usableFromInline let mode: MergeMode
  @usableFromInline let smoothing: Float
  @usableFromInline let first: First
  @usableFromInline let second: Second
  @usableFromInline let secondOffset: SIMD2<Float>

  @inlinable
  init(mode: MergeMode, smoothing: Float, first: First, second: Second, secondOffset: SIMD2<Float>)
  {
    self.mode = mode
    self.smoothing = smoothing
    self.first = first
    self.second = second
    self.secondOffset = secondOffset
  }
}

extension MergedShape: ShapeProtocol {
  @inlinable
  public var drawInstructions: some Sequence<ShapeMergingInstruction> {
    first.drawInstructions
      .chain(second.drawInstructions.lazy.map { instruction in
        guard case .push(let meta) = instruction else { return instruction }
        return .push(ShapeMetadata(meta.shape, meta.offset + secondOffset))
      })
      .chain(CollectionOfOne(.merge(self.mode)))
  }
}

public enum MergeMode: UInt32, Sendable {
  case union = 0
  case intersect = 1
  case xor = 2
  case subtract = 3
}

public struct MergeNode: Sendable {
  var mode: MergeMode
  var smoothing: Float
}

extension ShapeProtocol {
  @inlinable
  public func union<Other: ShapeProtocol>(
    _ other: Other, offset: SIMD2<Float> = .zero, smoothing: Float = 0
  ) -> MergedShape<Self, Other> {
    MergedShape(
      mode: .union, smoothing: smoothing, first: self, second: other, secondOffset: offset)
  }

  @inlinable
  public func intersect<Other: ShapeProtocol>(
    _ other: Other, offset: SIMD2<Float> = .zero, smoothing: Float = 0
  ) -> MergedShape<Self, Other> {
    MergedShape(
      mode: .intersect, smoothing: smoothing, first: self, second: other, secondOffset: offset)
  }

  @inlinable
  public func subtract<Other: ShapeProtocol>(
    _ other: Other, offset: SIMD2<Float> = .zero, smoothing: Float = 0
  ) -> MergedShape<Self, Other> {
    MergedShape(
      mode: .subtract, smoothing: smoothing, first: self, second: other, secondOffset: offset)
  }

  @inlinable
  public func xor<Other: ShapeProtocol>(
    _ other: Other, offset: SIMD2<Float> = .zero, smoothing: Float = 0
  ) -> MergedShape<Self, Other> {
    MergedShape(mode: .xor, smoothing: smoothing, first: self, second: other, secondOffset: offset)
  }
}
