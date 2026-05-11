import Reactivity

// handle compositor/window 
public class Runtime: @unchecked Sendable {
  @TaskLocal
  static var current: Runtime?
  public let root: RootNode
  var onFrames: [() -> Void] = []

  init (size: SIMD2<Float>) {
    root = RootNode(size: size)
  }

  func runOnFrame(_ block: @escaping () -> Void) {
    onFrames.append(block)
  }

  public func flushOnFrame() {
    for fn in onFrames {
      fn()
    }
  }
}

