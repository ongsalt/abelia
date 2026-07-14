import Foundation

typealias Pixel = [4 of UInt8]

/// Scanline fill with analytic (trapezoid) coverage.
///
/// `pixels` is tightly packed RGBA8, `width * height * 4` bytes long.
/// `shittyBlend(_ source: borrowing Pixel, _ destination: inout Pixel, _ opacity: Float)`
/// is left to the caller's side of the codebase.
public func fillScanline(
  path: borrowing Path,
  color: borrowing Color,
  transform: Affine = .identity,
  pixels: inout MutableSpan<UInt8>,
  width: Int,
  height: Int
) {
  precondition(pixels.count >= width * height * 4, "pixel buffer smaller than the image")
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

  let source: Pixel = [
    UInt8((color.red * 255).clamped(from: 0, to: 255)),
    UInt8((color.green * 255).clamped(from: 0, to: 255)),
    UInt8((color.blue * 255).clamped(from: 0, to: 255)),
    UInt8((color.alpha * 255).clamped(from: 0, to: 255)),
  ]

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

          coverage[x] += dy
          // trapezoid, see https://www.youtube.com/watch?v=B9bztU1sTFA
          fill[x] += dy * (1 - xMid)
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
      let winding = acc + fill[x]
      acc += coverage[x]

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

      let offset = 4 * (w * y + x)
      var destination: Pixel = [
        pixels[offset], pixels[offset + 1], pixels[offset + 2], pixels[offset + 3],
      ]
      shittyBlend(source, &destination, opacity)
      for channel in 0..<4 {
        pixels[offset + channel] = destination[channel]
      }
    }
  }
}

/// source-over onto straight (non-premultiplied) alpha, sRGB values blended as if they were
/// linear. That last part is the shitty part: it darkens the edge of a light shape on a dark
/// background. Good enough until the whole pipeline agrees on a working space.
func shittyBlend(_ source: borrowing Pixel, _ destination: inout Pixel, _ opacity: Float) {
  let sourceAlpha = Float(source[3]) / 255 * opacity.clamped(from: 0, to: 1)
  guard sourceAlpha > 0 else { return }

  let destinationAlpha = Float(destination[3]) / 255
  let outAlpha = sourceAlpha + destinationAlpha * (1 - sourceAlpha)
  guard outAlpha > 0 else {
    destination = [0, 0, 0, 0]
    return
  }

  for channel in 0..<3 {
    let s = Float(source[channel]) / 255
    let d = Float(destination[channel]) / 255
    // premultiply, composite, then divide back out to straight alpha
    let blended = (s * sourceAlpha + d * destinationAlpha * (1 - sourceAlpha)) / outAlpha
    destination[channel] = channelToByte(blended)
  }
  destination[3] = channelToByte(outAlpha)
}

@inline(__always)
private func channelToByte(_ value: Float) -> UInt8 {
  UInt8((value * 255).rounded().clamped(from: 0, to: 255))
}

/// triangle wave: 0 -> 1 over the first winding, 1 -> 0 over the second, and so on
@inline(__always)
private func evenOddOpacity(_ winding: Float) -> Float {
  let magnitude = min(abs(winding), Float(1 << 24))
  let fraction = magnitude.truncatingRemainder(dividingBy: 1)
  return Int(magnitude) % 2 == 0 ? fraction : 1 - fraction
}
