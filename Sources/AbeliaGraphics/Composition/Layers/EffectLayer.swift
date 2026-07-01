public class EffectLayer: _BaseLayer {
  public override var shape: any ShapeProtocol {
    get { _shape }
    set { _shape = newValue }
  }

  public var _shape: any ShapeProtocol = Shape.rect(width: 100, height: 100)
  public var effect: Effect = .blur(radius: 10)

  // size got ignored?

  public convenience init(
    offset: SIMD3<Float> = .zero,
    shape: (any ShapeProtocol)? = nil, effect: Effect = .blur(radius: 10)
  ) {
    self.init()
    self.offset = offset
    self.effect = effect
    if let shape {
      self.shape = shape
    }
  }
}
public enum Effect: Sendable {
  case blur(radius: Float)
  case refraction(amount: Float, height: Float, chromaticAberration: Float = 0)
  // case customShader
}
