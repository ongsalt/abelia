import Reactivity
import SwiftBlend2D

@Component
@MainActor
public func Canvas(size: Prop<SIMD2<Int>>, draw: @escaping (borrowing BLContext) -> Void) -> View {
  let box = Box()

  // TODO: clamp size
  @Computed
  var clamped = size.value.clamped(lowerBound: .one, upperBound: .init(.max, .max))

  let img = Computed {
    let img = BLImage(width: clamped.x, height: clamped.y, format: .prgb32)
    let ctx = BLContext(image: img)!
    ctx.compOp = .srcCopy
    ctx.setFillStyle(BLRgba32.transparentWhite)
    ctx.fillAll()

    ctx.compOp = .srcOver
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
    .width(Float(clamped.x))
    .height(Float(clamped.y))
}
