class Compositor {
  private(set) lazy var root: RootLayer = RootLayer(compositor: self)

  init() {
    _ = self.root
  }

  func rerender() {

  }

  public func resize(to size: Size<UInt32>) {

  }
}

class RootLayer: Layer {

}