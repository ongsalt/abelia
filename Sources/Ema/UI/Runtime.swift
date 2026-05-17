import EmaCore
import Reactivity
import Swinit

// handle compositor/window
@MainActor
public class Runtime {
  @MainActor
  static var current: Runtime?

  public let root: RootNode
  var onFrames: [() -> Void] = []

  // let eventLoop: EventLoop

  // NonLayoutNode id
  var compositor: Compositor?
  var window: Window?
  var eventLoop: EventLoop!
  var body: () -> Body

  init(contents: @escaping () -> Body) {
    // self.compositor = compositor
    // self.eventLoop = eventLoop
    self.body = contents
    root = RootNode(size: .zero)
    root.runtime = self
  }

  func initializeRendering(_ compositor: Compositor, _ window: Window) {
    self.compositor = compositor
    self.window = window

    let prev = Runtime.current
    Runtime.current = self

    // window.size is NOT client rect
    // TODO: fix it
    root.preferedWidth = Float(window.size.x)
    root.preferedHeight = Float(window.size.y)
    root.replaceChildren(self.body)
    root.initializeLayer()
    Runtime.current = prev
    self.flushOnFrame()
  }

  func resize(to size: SIMD2<Float>) {
    root.preferedWidth = size.x
    root.preferedHeight = size.y
    compositor?.resize(to: SIMD2(size))
  }

  func sendWindowEvent(_ event: WindowEvent) {
    switch event {
    case .resized(let size, let isFinal):
      self.resize(to: SIMD2(Float(size.width), Float(size.height)))
    case .closeRequested:
      // see if there is any closeRequest handler
      // for now...
      eventLoop.stop()
    default:
      do {}
    }
  }

  func runOnFrame(_ block: @escaping () -> Void) {
    onFrames.append(block)
  }

  func flushOnFrame() {
    for fn in onFrames {
      fn()
    }
    self.root.printTree()
    compositor?.root.printTree()
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

@MainActor
public func onDestroy(_ block: @escaping () -> Void) {
  guard let runtime = Runtime.current,
    let node = NonLayoutNode.current
  else {
    fatalError("onDestroy can only be called from a component")
  }

  runtime.registerOnDestroy(for: node, block)
}
