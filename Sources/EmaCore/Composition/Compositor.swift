import Dispatch
import SwiftBlend2D
import Synchronization

// public api @MainActor???
@MainActor
public class Compositor {
  private(set) public var root: RootLayer!
  private let renderer: Renderer
  private let rendererDispatchQueue: DispatchQueue = DispatchQueue(
    label: "lt.ongsa.Ema.EmaCore.rendererDispatchQueue")

  var dirtyLayers: [Layer] = []
  var dirtyLayerIds: Set<ObjectIdentifier> = []

  public init(surface: Surface, device: GraphicsDevice) {
    self.renderer = Renderer(surface: surface, device: device)

    self.root = RootLayer(compositor: self)
  }

  public func commit(recreateSwapchain: Bool = false) {
    self.markDirty(root)

    let dirtyLayers = dirtyLayers
    self.dirtyLayers = []
    dirtyLayerIds = []
    let batches = createBatches(dirtyLayers: dirtyLayers, root: self.root)

    print(batches[0].subpasses)

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

    // write index buffer, write vertex buffer
    let (vertex, index) = self.renderer.update(dirtyRects: [], dirtyLayers: dirtyLayers, batches: batches)
    withRenderingFn {
      // print("indexCount = \(index), vertexCount = \(vertex)")
      self.renderer.render(indexCount: UInt32(index), recreateSwapchain: recreateSwapchain)
    }
  }

  public func resize(to size: Size<UInt32>) {
    self.markDirty(root)
    self.commit(recreateSwapchain: true)
  }

  func markDirty(_ layer: Layer) {
    let (inserted, _) = dirtyLayerIds.insert(layer.id)
    if inserted {
      dirtyLayers.append(layer)
    }
  }

  // TODO: atomicInt
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

  public func createImage(from blImage: BLImage) -> Image {
    let texture = renderer.textureRegistry.createTexture(from: blImage, usages: .static)

    return Image(texture: texture)
  }
}

public class RootLayer: Layer, @unchecked Sendable {

}
