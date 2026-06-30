// TODO: might do R tree later
struct ApproximateCoverage {
  var rects: [Rect] = []
}

extension ApproximateCoverage {
  mutating func add(_ node: RenderNode) {
    let bounds = node.shape.bounds.atOrigin
  }

  func overlaps(with node: RenderNode) {

  }
}

struct BlurRegion {
  let shape: any ShapeProtocol
  let affine: Affine
  let radius: Float
}

struct EffectRegion {
  let shape: any ShapeProtocol
  let affine: Affine
  let effect: Effect
}

struct EffectNode {
  let samplingTextureIndex: UInt32
  let region: EffectRegion
}

struct BlurNode {
  let samplingTextureIndex: UInt32
  let region: BlurRegion
}
