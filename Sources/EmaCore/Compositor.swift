class Compositor {
  private(set) lazy var root: RootLayer = RootLayer(compositor: self)

  init() {
    _ = self.root
  }

  func rerender() {

  }
}

class RootLayer: Layer {

}