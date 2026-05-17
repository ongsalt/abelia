import Reactivity
import SwiftBlend2D

@Component
@MainActor
public func Canvas(size: SIMD2<Float>, draw: @escaping (borrowing BLContext) -> Void) -> View {
  let box = Box()

  let img = Computed {
    let img = BLImage(width: Int(size.x), height: Int(size.y), format: .prgb32)
    let ctx = BLContext(image: img)!
    // implicitly track anything read in this?
    draw(ctx)
    ctx.end()
    return img
    // _ = box.layoutNode.size
  }

  Effect {
    guard let layer = box.layoutNode.layer else { return }
    // TODO: api for canvas so that we dont need to reallocate image every time its content changed
    let texture = layer.compositor.createImage(from: img.value)
    layer.brush = .image(texture)
  }

  return box
    .width(size.x)
    .height(size.y)
}
