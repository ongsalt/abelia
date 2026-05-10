public class Compositor {
  private let graphicsContext: GraphicsContext
  private let surface: Surface
  private(set) lazy var root: RootLayer = RootLayer(compositor: self)

  // private var layerStorage: GPULayerStorage

  init(graphicsContext: GraphicsContext, surface: Surface) {
    self.graphicsContext = graphicsContext
    self.surface = surface

    _ = self.root
  }

  func rerender() {

  }

  public func resize(to size: Size<UInt32>) {

  }
}

class RootLayer: Layer {

}

