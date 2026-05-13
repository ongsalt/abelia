// public api @MainActor???
@MainActor
public class Compositor {
  private(set) lazy var root: RootLayer = RootLayer(compositor: self)
  private let renderer: Renderer
  // private var layerStorage: GPULayerStorage

  public init(graphicsContext: GraphicsContext, surface: Surface, device: GraphicsDevice) {
    self.renderer = Renderer(graphicsContext: graphicsContext, surface: surface, device: device)
    _ = self.root
  }

  func recomposite() async {
    // await renderer.updateLayers { @MainActor layerStorage in
    //   self.flushAnimations()
    //   for layer in self.dirtyNodes {
    //     layerStorage.update(layer)
    //   }
    // }
    // tell the renderer which layer propery changed (update LayerStorage)
    // and what need to be rerender
  }

  public func resize(to size: Size<UInt32>) {

  }
}

class RootLayer: Layer {

}

