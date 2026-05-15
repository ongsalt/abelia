import Dispatch
import Synchronization

// public api @MainActor???
@MainActor
public class Compositor {
  private(set) lazy var root: RootLayer = RootLayer(compositor: self)
  private let renderer: Renderer
  private let rendererDispatchQueue: DispatchQueue = DispatchQueue(
    label: "lt.ongsa.Ema.EmaCore.rendererDispatchQueue")
  // private var layerStorage: GPULayerStorage

  public init(surface: Surface, device: GraphicsDevice) {
    self.renderer = Renderer(surface: surface, device: device)
    _ = self.root
  }

  let rendering = Mutex(0)
  public func recomposite(resized: Bool = false) {
    let willContinue = rendering.withLock { rendering in
      if rendering >= 2 {
        return false
      }
      rendering += 1
      return true
    }

    if !willContinue { return }

    rendererDispatchQueue.async { [self] in
      let clock = ContinuousClock()
      let time = clock.measure {
        if resized {
          self.renderer.forceRenderAfterResize()
        } else {
          self.renderer.render()
        }
      }
      rendering.withLock { rendering in
        rendering -= 1
      }
      print("time = \(time / .milliseconds(1))ms")
    }

    // await renderer.updateLayers { @MainActor layerStorage in
    //   self.flushAnimations()
    //   for layer in self.dirtyNodes {
    //     layerStorage.update(layer)
    //   }
    // }
    // tell the renderer which layer propery changed (update LayerStorage)
    // and what need to be rerender
  }

  // TODO: smooth resize
  public func resize(to size: Size<UInt32>) {
    recomposite(resized: true)
    // windows fuck you
    // if renderer.isNextImageReady {
    //   print("render: \(size)")
    //   self.renderer.forceRenderAfterResize()
    //   // and we shuold NOT ack this until
    // } else {
    //   // self.renderer.scheduleRerender()
    // }
  }
}

class RootLayer: Layer {

}
