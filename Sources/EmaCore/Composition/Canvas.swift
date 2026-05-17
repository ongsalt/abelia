import Foundation
import SwiftBlend2D

public func sample6(width: Int, height: Int) throws -> BLImage {
  let img = BLImage(width: width, height: height, format: .prgb32)
  let ctx = BLContext(image: img)!

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

  ctx.end()
  return img
}

extension TextureRegistry {
  func createTexture(from image: BLImage, usages: TextureUsages) -> Texture {
    let data = image.getImageData()
    return createTexture(
      fromCpuBuffer: UnsafeRawBufferPointer(
        start: data.pixelData, count: data.stride * Int(data.size.h)),
      size: SIMD2(UInt32(data.size.w), UInt32(data.size.h)),
      usages: usages)
  }
}

public class Image {
  let texture: Texture

  init(texture: Texture) {
    self.texture = texture
  }
}

extension Image: CompositionTextureProtocol {
    public var textureIndex: UInt32 { texture.textureIndex }
}