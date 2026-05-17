import Ema
import Reactivity
import SwiftBlend2D

runApp {
  Row {
    Box(alignment: .center) {
      Box()
        .width(12)
        .height(300)
        .color(.white.with(alpha: 0.2))
    }
    .fillMaxHeight()
    .width(300)
    .color(.blue)

    Box {
      Canvas(size: .init(500, 500)) { ctx in
        ctx.compOp = .srcCopy
        ctx.fillAll()

        var linear = BLGradient(linear: BLLinearGradientValues(x0: 0, y0: 0, x1: 0, y1: 480))
        linear.addStop(0.0, BLRgba32(argb: 0xFFFF_FFFF))
        linear.addStop(1.0, BLRgba32(argb: 0xFF1F_7FFF))

        let path = BLPath()
        path.moveTo(x: 119, y: 49)
        path.cubicTo(x1: 259, y1: 29, x2: 99, y2: 279, x3: 275, y3: 267)
        path.cubicTo(x1: 537, y1: 245, x2: 300, y2: -170, x3: 274, y3: 430)

        ctx.compOp = .srcOver
        ctx.setStrokeStyle(linear)
        ctx.setStrokeWidth(15)
        ctx.setStrokeStartCap(.round)
        ctx.setStrokeEndCap(.butt)
        ctx.strokePath(path)
      }
    }
    .fillMaxHeight()
    .color(.white)
  }
  .fillMaxSize()
}
