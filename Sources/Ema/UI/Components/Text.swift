import Reactivity
import SwiftBlend2D

// oh wait, we need special layout handling for this
// for now just do this
@Component
@MainActor
public func Text(_ text: Prop<some StringProtocol>, size: Prop<Float> = .default(0)) -> View {
  // TODO: figure out how to bundle this
  let face = try! BLFontFace(fromFile: "C:/Windows/Fonts/arial.ttf")

  @Computed
  var font = BLFont(fromFace: face, size: size.value)

  @Computed
  var matrics = font.getTextMetrics(text.value)

  // wtf, is there no bound check or what
  let safeArea  = 0

  @Computed
  var w = Int(matrics.advance.x) + safeArea
  // yeah this is shitty

  @Computed
  var h = Int(font.metrics.yMax - font.metrics.yMin) + safeArea

  // print("w,h = \(w) \(h)")

  return Canvas(size: SIMD2(w, h)) { ctx in
    ctx.compOp = .srcCopy
  
    ctx.setFillStyleRgba32(0xFFFF_FFFF)
    ctx.fillText(text.value, at: BLPoint(x: 0, y: Double(font.metrics.ascent)), font: font)
  }
}

extension BLBox {
  var sizeF: SIMD2<Float> {
    SIMD2(Float(w), Float(h))
  }
}