import Foundation

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
  case merge(MergeMode, smoothing: Float)
  case push(ShapeMetadata)
  /// unary op applied to the top of the merge stack (opRound / opOnion)
  case modify(ModifyMode, radius: Float)
}

/// Unary distance-field operators from https://iquilezles.org/articles/distfunctions2d/
public enum ModifyMode: UInt32, Sendable {
  /// `d - r`: grows the shape outward, rounding convex corners
  case round = 0
  /// `abs(d) - r`: turns the shape into an annular ring of half-thickness `r`
  case onion = 1
}

public protocol ShapeProtocol: Sendable {
  associatedtype DrawInstructions: Sequence<ShapeMergingInstruction>
  var drawInstructions: DrawInstructions { get }
  var bounds: Rect { get }
  func sdf(_ p: SIMD2<Float>) -> Float
  func contains(_ point: SIMD2<Float>) -> Bool
}

/// perimeterOffset just directly subtract the distance, effectively moving isoperimeter out and rounding it
///
/// For the regular shapes (pentagon…quadraticCircle) `radius` is the circumradius:
/// the shape's vertices/tips lie on a circle of that radius, so the axis-aligned bound is `radius`.
public enum Shape: Sendable {
  case rect(width: Float, height: Float, cornerRadius: Float = 0, cornerDegree: Float = 4)
  case arc(radius: Float, angle: Angle, thickness: Float)
  case pie(radius: Float, angle: Angle, perimeterOffset: Float = 0)
  case ellipse(radiusX: Float, radiusY: Float)
  case pentagon(radius: Float)
  case hexagon(radius: Float)
  case octagon(radius: Float)
  case hexagram(radius: Float)
  /// `innerRadiusFactor` in (0, 1): ratio of the inner to the outer vertex radius; 0.382 gives the classic 5-point star
  case pentagram(radius: Float, innerRadiusFactor: Float = 0.382)
  case quadraticCircle(radius: Float)
  /// arbitrary closed polygon; `vertices` are in local space (0,0 is the center). Stored in a dedicated GPU vertex buffer.
  case polygon(_ vertices: [SIMD2<Float>], perimeterOffset: Float = 0)
}

extension Shape {
  public static func circle(_ radius: Float) -> Self {
    .rect(width: radius * 2, height: radius * 2, cornerRadius: radius, cornerDegree: 2)
  }
}

// we basically need 2 copy of sdf code, one in the shader, one here
extension Shape: ShapeProtocol {
  @inlinable
  public var drawInstructions: some Sequence<ShapeMergingInstruction> {
    CollectionOfOne(.push(ShapeMetadata(self, .zero)))
  }

  public var bounds: Rect {
    switch self {
    case .rect(let width, let height, _, _):
      return Rect(center: .zero, size: SIMD2(width, height))
    case .arc(let radius, _, let thickness):
      let s = (radius + thickness / 2) * 2
      return Rect(center: .zero, size: SIMD2(s, s))
    case .pie(let radius, _, let perimeterOffset):  // angle unused for bounds
      let s = max(radius + perimeterOffset, 0) * 2
      return Rect(center: .zero, size: SIMD2(s, s))
    case .ellipse(let radiusX, let radiusY):
      return Rect(center: .zero, size: SIMD2(radiusX * 2, radiusY * 2))
    case .pentagon(let radius), .hexagon(let radius), .octagon(let radius),
      .hexagram(let radius), .pentagram(let radius, _), .quadraticCircle(let radius):
      return Rect(center: .zero, size: SIMD2(radius * 2, radius * 2))
    case .polygon(let vertices, let perimeterOffset):
      guard let first = vertices.first else { return .zero }
      var lo = first, hi = first
      for v in vertices {
        lo = SIMD2(min(lo.x, v.x), min(lo.y, v.y))
        hi = SIMD2(max(hi.x, v.x), max(hi.y, v.y))
      }
      return Rect(topLeft: lo, size: hi - lo).padded(max(perimeterOffset, 0))
    }
  }

  public func sdf(_ p: SIMD2<Float>) -> Float {
    switch self {
    case .rect(let width, let height, let cornerRadius, let cornerDegree):
      return _sdfRoundRect(p, size: SIMD2(width, height), radius: cornerRadius, degree: cornerDegree)
    case .arc(let radius, let angle, let thickness):
      return _sdfArc(p, radius: radius, angle: angle.radians, thickness: thickness)
    case .pie(let radius, let angle, let perimeterOffset):
      return _sdfPie(p, radius: radius, angle: angle.radians, perimeterOffset: perimeterOffset)
    case .ellipse(let radiusX, let radiusY):
      return _sdfEllipse(p, ab: SIMD2(radiusX, radiusY))
    case .pentagon(let radius):
      return _sdfPentagon(p, radius)
    case .hexagon(let radius):
      return _sdfHexagon(p, radius)
    case .octagon(let radius):
      return _sdfOctagon(p, radius)
    case .hexagram(let radius):
      return _sdfHexagram(p, radius)
    case .pentagram(let radius, let innerRadiusFactor):
      return _sdfPentagram(p, radius, innerRadiusFactor)
    case .quadraticCircle(let radius):
      return _sdfQuadraticCircle(p, radius)
    case .polygon(let vertices, let perimeterOffset):
      return _sdfPolygon(p, vertices, perimeterOffset)
    }
  }

  public func contains(_ point: SIMD2<Float>) -> Bool {
    // fast algebraic test for ellipse: (x/a)²+(y/b)² <= 1
    if case .ellipse(let rx, let ry) = self {
      let nx = point.x / rx, ny = point.y / ry
      return nx * nx + ny * ny <= 1
    }
    return sdf(point) <= 0
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
      .chain(CollectionOfOne(.merge(self.mode, smoothing: self.smoothing)))
  }

  public var bounds: Rect {
    let a = first.bounds
    let b = second.bounds.offset(secondOffset)
    let left = min(a.left, b.left)
    let top = min(a.top, b.top)
    return Rect(topLeft: SIMD2(left, top), size: SIMD2(max(a.right, b.right) - left, max(a.bottom, b.bottom) - top))
      .padded(self.smoothing / 2)
  }

  public func sdf(_ p: SIMD2<Float>) -> Float {
    let d1 = first.sdf(p)
    let d2 = second.sdf(p - secondOffset)
    let k = smoothing
    switch mode {
    case .union:
      return k <= 0 ? min(d1, d2) : _sdfSmoothUnion(d1, d2, k)
    case .intersect:
      return k <= 0 ? max(d1, d2) : -_sdfSmoothUnion(-d1, -d2, k)
    case .subtract:
      return k <= 0 ? max(d1, -d2) : -_sdfSmoothUnion(-d1, d2, k)
    case .xor:
      return max(min(d1, d2), -max(d1, d2))
    }
  }

  public func contains(_ point: SIMD2<Float>) -> Bool {
    sdf(point) <= 0
  }
}

/// Wraps a shape with a unary distance-field operator (opRound / opOnion).
public struct ModifiedShape<Base: ShapeProtocol>: Sendable {
  @usableFromInline let mode: ModifyMode
  @usableFromInline let radius: Float
  @usableFromInline let base: Base

  @inlinable
  init(mode: ModifyMode, radius: Float, base: Base) {
    self.mode = mode
    self.radius = radius
    self.base = base
  }
}

extension ModifiedShape: ShapeProtocol {
  @inlinable
  public var drawInstructions: some Sequence<ShapeMergingInstruction> {
    base.drawInstructions.chain(CollectionOfOne(.modify(self.mode, radius: self.radius)))
  }

  public var bounds: Rect {
    // both operators can push the outer isoline out by `radius`
    base.bounds.padded(max(radius, 0))
  }

  public func sdf(_ p: SIMD2<Float>) -> Float {
    let d = base.sdf(p)
    switch mode {
    case .round: return d - radius
    case .onion: return abs(d) - radius
    }
  }

  public func contains(_ point: SIMD2<Float>) -> Bool {
    sdf(point) <= 0
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

  /// opRound: grow the shape outward by `radius`, rounding its convex corners.
  @inlinable
  public func rounded(_ radius: Float) -> ModifiedShape<Self> {
    ModifiedShape(mode: .round, radius: radius, base: self)
  }

  /// opOnion: hollow the shape into an annular ring of half-thickness `radius`.
  @inlinable
  public func onion(_ radius: Float) -> ModifiedShape<Self> {
    ModifiedShape(mode: .onion, radius: radius, base: self)
  }
}

// MARK: - SDF helpers

private func _sdfRoundRect(_ position: SIMD2<Float>, size: SIMD2<Float>, radius: Float, degree: Float) -> Float {
  let vx = abs(position.x) - size.x / 2 + radius
  let vy = abs(position.y) - size.y / 2 + radius
  let mx = max(vx, 0), my = max(vy, 0)
  let outer = pow(pow(mx, degree) + pow(my, degree), 1 / degree)
  return min(0, max(vx, vy)) + outer - radius
}

private func _sdfArc(_ p: SIMD2<Float>, radius: Float, angle: Float, thickness: Float) -> Float {
  let s = sin(angle * 0.5)
  let c = cos(angle * 0.5)
  let qx = abs(p.x), qy = p.y
  let dist = (c * qx > s * qy)
    ? sqrt((qx - s * radius) * (qx - s * radius) + (qy - c * radius) * (qy - c * radius))
    : abs(sqrt(qx * qx + qy * qy) - radius)
  return dist - thickness * 0.5
}

private func _sdfPie(_ p: SIMD2<Float>, radius: Float, angle: Float, perimeterOffset: Float) -> Float {
  let s = sin(angle * 0.5)
  let c = cos(angle * 0.5)
  let qx = abs(p.x), qy = p.y
  let t = min(max(qx * s + qy * c, 0), radius)
  let l = (qx * qx + qy * qy).squareRoot() - radius
  let dx = qx - s * t, dy = qy - c * t
  let m = (dx * dx + dy * dy).squareRoot()
  let sign: Float = c * qx - s * qy >= 0 ? 1 : -1
  return max(l, m * sign) - perimeterOffset
}

private func _sdfSmoothUnion(_ d1: Float, _ d2: Float, _ k: Float) -> Float {
  let h = max(0, min(1, 0.5 + 0.5 * (d2 - d1) / k))
  return d2 + h * (d1 - d2) - k * h * (1 - h)
}

// ported from https://www.shadertoy.com/view/4sS3zz
private func _sdfEllipse(_ position: SIMD2<Float>, ab: SIMD2<Float>) -> Float {
  var px = abs(position.x), py = abs(position.y)
  var ax = ab.x, ay = ab.y
  if px > py { swap(&px, &py); swap(&ax, &ay) }
  let l = ay * ay - ax * ax
  let m = ax * px / l;  let m2 = m * m
  let n = ay * py / l;  let n2 = n * n
  let c = (m2 + n2 - 1) / 3
  let c3 = c * c * c
  let q = c3 + m2 * n2 * 2
  let d = c3 + m2 * n2
  let g = m + m * n2
  let co: Float
  if d < 0 {
    let h = acos(q / c3) / 3
    let s = cos(h), t = sin(h) * sqrt(3)
    let rx = sqrt(-c * (s + t + 2) + m2)
    let ry = sqrt(-c * (s - t + 2) + m2)
    co = (ry + (l >= 0 ? 1 : -1) * rx + abs(g) / (rx * ry) - m) / 2
  } else {
    let h = 2 * m * n * sqrt(d)
    let cbrt = { (x: Float) -> Float in x < 0 ? -pow(-x, 1/3) : pow(x, 1/3) }
    let s = cbrt(q + h), u = cbrt(q - h)
    let rx = -s - u - c * 4 + 2 * m2
    let ry = (s - u) * sqrt(3)
    let rm = sqrt(rx * rx + ry * ry)
    co = (ry / sqrt(rm - rx) + 2 * g / rm - m) / 2
  }
  let rx = ax * co, ry = ay * sqrt(1 - co * co)
  let dx = rx - px, dy = ry - py
  return sqrt(dx * dx + dy * dy) * (py >= ry ? 1 : -1)
}

// MARK: - Regular polygon / star SDFs (ported from https://iquilezles.org/articles/distfunctions2d/)
// `radius` is the circumradius; iq's functions take the inradius/tip radius, so we rescale at the call site.

@inline(__always) private func _dot(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
  a.x * b.x + a.y * b.y
}
@inline(__always) private func _len(_ a: SIMD2<Float>) -> Float {
  (a.x * a.x + a.y * a.y).squareRoot()
}
@inline(__always) private func _abs(_ a: SIMD2<Float>) -> SIMD2<Float> {
  SIMD2(abs(a.x), abs(a.y))
}

private func _sdfPentagon(_ p0: SIMD2<Float>, _ radius: Float) -> Float {
  let r = radius * 0.809016994  // circumradius -> inradius
  let k = SIMD3<Float>(0.809016994, 0.587785252, 0.726542528)
  var p = p0
  p.x = abs(p.x)
  p -= 2 * min(_dot(SIMD2(-k.x, k.y), p), 0) * SIMD2(-k.x, k.y)
  p -= 2 * min(_dot(SIMD2(k.x, k.y), p), 0) * SIMD2(k.x, k.y)
  p -= SIMD2(p.x.clamped(from: -r * k.z, to: r * k.z), r)
  return _len(p) * (p.y < 0 ? -1 : 1)
}

private func _sdfHexagon(_ p0: SIMD2<Float>, _ radius: Float) -> Float {
  let r = radius * 0.866025404  // circumradius -> inradius
  let k = SIMD3<Float>(-0.866025404, 0.5, 0.577350269)
  var p = _abs(p0)
  p -= 2 * min(_dot(SIMD2(k.x, k.y), p), 0) * SIMD2(k.x, k.y)
  p -= SIMD2(p.x.clamped(from: -k.z * r, to: k.z * r), r)
  return _len(p) * (p.y < 0 ? -1 : 1)
}

private func _sdfOctagon(_ p0: SIMD2<Float>, _ radius: Float) -> Float {
  let r = radius * 0.923879533  // circumradius -> inradius
  let k = SIMD3<Float>(-0.9238795325, 0.3826834323, 0.4142135623)
  var p = _abs(p0)
  p -= 2 * min(_dot(SIMD2(k.x, k.y), p), 0) * SIMD2(k.x, k.y)
  p -= 2 * min(_dot(SIMD2(-k.x, k.y), p), 0) * SIMD2(-k.x, k.y)
  p -= SIMD2(p.x.clamped(from: -k.z * r, to: k.z * r), r)
  return _len(p) * (p.y < 0 ? -1 : 1)
}

private func _sdfHexagram(_ p0: SIMD2<Float>, _ radius: Float) -> Float {
  let r = radius * 0.5  // circumradius (tip) -> iq r
  let k = SIMD4<Float>(-0.5, 0.8660254038, 0.5773502692, 1.7320508076)
  var p = _abs(p0)
  p -= 2 * min(_dot(SIMD2(k.x, k.y), p), 0) * SIMD2(k.x, k.y)
  p -= 2 * min(_dot(SIMD2(k.y, k.x), p), 0) * SIMD2(k.y, k.x)
  p -= SIMD2(p.x.clamped(from: r * k.z, to: r * k.w), r)
  return _len(p) * (p.y < 0 ? -1 : 1)
}

private func _sdfPentagram(_ p0: SIMD2<Float>, _ radius: Float, _ rf: Float) -> Float {
  let k1 = SIMD2<Float>(0.809016994375, -0.587785252292)
  let k2 = SIMD2<Float>(-k1.x, k1.y)
  var p = p0
  p.x = abs(p.x)
  p -= 2 * max(_dot(k1, p), 0) * k1
  p -= 2 * max(_dot(k2, p), 0) * k2
  p.x = abs(p.x)
  p.y -= radius
  let ba = rf * SIMD2<Float>(-k1.y, k1.x) - SIMD2<Float>(0, 1)
  let h = (_dot(p, ba) / _dot(ba, ba)).clamped(from: 0, to: radius)
  return _len(p - ba * h) * ((p.y * ba.x - p.x * ba.y) < 0 ? -1 : 1)
}

private func _sdfQuadraticCircle(_ p0: SIMD2<Float>, _ radius: Float) -> Float {
  var p = _abs(p0 / radius)
  if p.y > p.x { p = SIMD2(p.y, p.x) }
  let a = p.x - p.y
  let b = p.x + p.y
  let c = (2 * b - 1) / 3
  let h = a * a + c * c * c
  var t: Float
  if h >= 0 {
    let hs = h.squareRoot()
    let m = hs - a
    t = (m < 0 ? -1 : 1) * pow(abs(m), 1.0 / 3) - pow(hs + a, 1.0 / 3)
  } else {
    let z = (-c).squareRoot()
    let v = acos(a / (c * z)) / 3
    t = -z * (cos(v) + sin(v) * 1.732050808)
  }
  t *= 0.5
  let w = SIMD2(-t, t) + SIMD2(0.75, 0.75) - SIMD2(t * t, t * t) - p
  return _len(w) * ((a * a * 0.5 + b - 1.5) < 0 ? -1 : 1) * radius
}

private func _sdfPolygon(
  _ p: SIMD2<Float>, _ v: [SIMD2<Float>], _ perimeterOffset: Float
) -> Float {
  let n = v.count
  guard n > 0 else { return .greatestFiniteMagnitude }
  var d = _dot(p - v[0], p - v[0])
  var s: Float = 1
  var j = n - 1
  for i in 0..<n {
    let e = v[j] - v[i]
    let w = p - v[i]
    let b = w - e * (_dot(w, e) / _dot(e, e)).clamped(from: 0, to: 1)
    d = min(d, _dot(b, b))
    let c0 = p.y >= v[i].y
    let c1 = p.y < v[j].y
    let c2 = e.x * w.y > e.y * w.x
    if (c0 && c1 && c2) || (!c0 && !c1 && !c2) { s = -s }
    j = i
  }
  return s * d.squareRoot() - perimeterOffset
}
