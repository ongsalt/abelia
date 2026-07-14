import Foundation

/// RGBA8, straight (non-premultiplied) alpha
public typealias Pixel = [4 of UInt8]

/// Scanline fill with analytic (trapezoid) coverage.
///
/// `pixels` is tightly packed RGBA8, one `Pixel` per pixel, `width * height` long. A byte buffer
/// can be viewed as one with `rawBuffer.bindMemory(to: Pixel.self)`: `Pixel` is 4 bytes, stride 4.
public func fillScanline(
  path: borrowing Path,
  color: borrowing Color,
  transform: Affine = .identity,
  pixels: inout MutableSpan<Pixel>,
  width: Int,
  height: Int
) {
  precondition(pixels.count >= width * height, "pixel buffer smaller than the image")
  guard width > 0, height > 0 else { return }

  let lines = path.breakIntoLines(transform: transform)
  guard !lines.isEmpty else { return }

  let fillRule = path.fillRule

  var linesByStartY: [Int: [Int]] = [:]
  var linesByEndY: [Int: [Int]] = [:]

  var minY = Int.max
  var maxY = Int.min

  for (index, line) in lines.enumerated() {
    let (y1, y2) = line.yBounds
    minY = min(y1, minY)
    maxY = max(y2, maxY)
    linesByStartY[y1, default: []].append(index)
    linesByEndY[y2, default: []].append(index)
  }

  // a path may sit partly outside the image; the tables and the row slice are only valid inside it
  minY = max(minY, 0)
  maxY = min(maxY, height - 1)
  guard minY <= maxY else { return }

  let w = width

  // sorted (by x) indices into `lines`
  var activeSegments: [Int] = []

  // fill of the current pixel
  var fillTable = [Float](repeating: 0, count: w)
  // fill of everything after the current pixel
  var coverageTable = [Float](repeating: 0, count: w)

  // decode once per fill, not once per pixel; alpha carries no transfer curve
  let linear = color.linearized
  let source = SIMD4<Float>(linear.red, linear.green, linear.blue, linear.alpha)

  for y in minY...maxY {
    // update active segment list, sorted by x
    if let starting = linesByStartY[y] {
      activeSegments.append(contentsOf: starting)
      // its nearly sorted btw
      activeSegments.sort { lines[$0].minX < lines[$1].minX }
    }

    var rowStart = w
    var rowEnd = 0
    let shouldSkip = activeSegments.isEmpty

    if !shouldSkip {
      var fill = fillTable.mutableSpan
      var coverage = coverageTable.mutableSpan
      fill.update(repeating: 0)
      coverage.update(repeating: 0)

      for lineIndex in activeSegments {
        // clip it to the y-strip
        guard let strip = lines[lineIndex].clipY(from: Float(y), to: Float(y + 1)) else {
          continue
        }

        let (xStart, xEnd) = strip.xBounds
        let clampedStart = max(xStart, 0)
        let clampedEnd = min(xEnd, w - 1)
        guard clampedStart <= clampedEnd else { continue }

        rowStart = min(rowStart, clampedStart)
        rowEnd = max(rowEnd, clampedEnd)

        for x in clampedStart...clampedEnd {
          guard let cell = strip.clipX(from: Float(x), to: Float(x + 1)) else {
            continue
          }

          let dy = cell.end.y - cell.start.y
          let xMid = (cell.start.x + cell.end.x) / 2 - Float(x)

          // x is clamped to 0..<w and the tables are w long
          coverage[unchecked: x] += dy
          // trapezoid, see https://www.youtube.com/watch?v=B9bztU1sTFA
          fill[unchecked: x] += dy * (1 - xMid)
        }
      }
    }

    // drop the segments that end on this row
    if let ending = linesByEndY[y] {
      let done = Set(ending)
      activeSegments.removeAll { done.contains($0) }
    }

    guard !shouldSkip, rowStart <= rowEnd else { continue }

    // resolve pass
    let fill = fillTable.span
    let coverage = coverageTable.span
    var acc: Float = 0

    for x in rowStart...rowEnd {
      // rowStart/rowEnd came from clamped line bounds, so they are inside the tables
      let winding = acc + fill[unchecked: x]
      acc += coverage[unchecked: x]

      let opacity =
        switch fillRule {
        case .nonZero:
          min(abs(winding), 1)
        case .evenOdd:
          evenOddOpacity(winding)
        }

      if opacity < .ulpOfOne {
        continue
      }

      // y < height, x < w, and `pixels` holds at least width * height of them
      blend(source, &pixels[unchecked: w * y + x], opacity)
    }
  }
}

/// Source-over in linear light. `source` is linear RGB with straight alpha in `w`; `destination`
/// is sRGB-encoded RGBA8, so it gets decoded, composited premultiplied, and re-encoded. Blending
/// the encoded values directly is what darkens the edges of a light shape on a dark background.
@inline(__always)
func blend(_ source: SIMD4<Float>, _ destination: inout Pixel, _ opacity: Float) {
  let sourceAlpha = source.w * opacity.clamped(from: 0, to: 1)
  guard sourceAlpha > 0 else { return }

  let destinationAlpha = Float(destination[3]) / 255
  let outAlpha = sourceAlpha + destinationAlpha * (1 - sourceAlpha)
  guard outAlpha > 0 else {
    destination = [0, 0, 0, 0]
    return
  }

  for channel in 0..<3 {
    let d = srgbToLinearTable[Int(destination[channel])]
    // premultiplied source-over, then divide back out to straight alpha
    let composited =
      source[channel] * sourceAlpha + d * destinationAlpha * (1 - sourceAlpha)
    destination[channel] = linearToSrgbByte(composited / outAlpha)
  }
  destination[3] = UInt8((outAlpha * 255).rounded().clamped(from: 0, to: 255))
}

/// 256 entries, so decoding the destination is a load instead of a `pow`
private let srgbToLinearTable: [Float] = (0...255).map { byte in
  let x = Float(byte) / 255
  return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
}

@inline(__always)
private func linearToSrgbByte(_ linear: Float) -> UInt8 {
  let x = linear.clamped(from: 0, to: 1)
  let encoded = x <= 0.0031308 ? x * 12.92 : 1.055 * pow(x, 1 / 2.4) - 0.055
  return UInt8((encoded * 255).rounded())
}

/// triangle wave: 0 -> 1 over the first winding, 1 -> 0 over the second, and so on
@inline(__always)
private func evenOddOpacity(_ winding: Float) -> Float {
  let magnitude = min(abs(winding), Float(1 << 24))
  let fraction = magnitude.truncatingRemainder(dividingBy: 1)
  return Int(magnitude) % 2 == 0 ? fraction : 1 - fraction
}
