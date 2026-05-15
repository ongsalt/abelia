import Dispatch
import Synchronization

// public api @MainActor???
@MainActor
public class Compositor {
  private(set) public lazy var root: RootLayer = RootLayer(compositor: self)
  private let renderer: Renderer
  private let rendererDispatchQueue: DispatchQueue = DispatchQueue(
    label: "lt.ongsa.Ema.EmaCore.rendererDispatchQueue")
  // private var layerStorage: GPULayerStorage

  public init(surface: Surface, device: GraphicsDevice) {
    self.renderer = Renderer(surface: surface, device: device)
    _ = self.root
  }

  public func recomposite() {
    let dirtyLayers = dirtyLayers
    self.dirtyLayers = []
    dirtyLayerIds = []
    let batches = createBatches(dirtyLayers: [self.root], root: self.root)
    // fuckk

    // for batch in batches {
    //   let layers = batch.subpasses.flatMap {
    //     switch $0.inner {
    //     case .composite(let layers):
    //       return layers
    //     case .effect:
    //       return []
    //     }
    //   }
    // }

    self.renderer.update(dirtyRects: [], dirtyLayers: dirtyLayers, batches: batches)
    // write index buffer, write vertex buffer
    withRenderingFn {
      self.renderer.render()
    }
  }

  // TODO: smooth resize
  public func resize(to size: Size<UInt32>) {
    withRenderingFn {
      // just mark root node as dirty
      self.renderer.forceRenderAfterResize()
    }
  }

  var dirtyLayers: [Layer] = []
  var dirtyLayerIds: Set<ObjectIdentifier> = []
  func markDirty(_ layer: Layer) {
    let (inserted, _) = dirtyLayerIds.insert(layer.id)
    if inserted {
      dirtyLayers.append(layer)
    }
  }

  let rendering = Mutex(0)
  private func withRenderingFn(_ block: @Sendable @escaping () -> Void) {
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
        block()
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
}

public class RootLayer: Layer, @unchecked Sendable {

}
