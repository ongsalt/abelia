import Reactivity

// handle compositor/window
public class Runtime: @unchecked Sendable {
  @TaskLocal
  static var current: Runtime?
  public let root: RootNode
  var onFrames: [() -> Void] = []

  // NonLayoutNode id

  init(size: SIMD2<Float>) {
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

  var onDestroyCallbacks: [ObjectIdentifier: [() -> Void]] = [:]
  func flushOnDestroy(for node: NonLayoutNode) {
    if let fns = self.onDestroyCallbacks[node.id] {
      for fn in fns {
        fn()
      }
      self.onDestroyCallbacks[node.id] = nil
    }
  }

  func registerOnDestroy(for node: NonLayoutNode, _ block: @escaping () -> Void) {
    self.onDestroyCallbacks[node.id, default: []].append(block)
  }
}

public func onDestroy(_ block: @escaping () -> Void) {
  guard let runtime = Runtime.current,
    let node = NonLayoutNode.current
  else {
    fatalError("onDestroy can only be called from a component")
  }

  runtime.registerOnDestroy(for: node, block)
}
