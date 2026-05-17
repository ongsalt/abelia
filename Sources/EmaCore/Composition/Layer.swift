import Reactivity

@MainActor
public class Layer: Identifiable {
  var compositor: Compositor
  var label: String?

  package init(compositor: Compositor) {
    self.compositor = compositor
  }

  @Signal
  public package(set) var parent: Layer?
  public package(set) var children: [Layer] = []  // it shuold be ordered set actually

  public func insert(_ layer: Layer, before: Layer? = nil) {
    compositor.markDirty(layer)
    children.append(layer)
    layer.parent = self
  }

  public func remove(_ layer: Layer) {
    layer.parent = nil
    children.removeAll { $0.id == layer.id }
  }

  @Signal
  public var opacity: Float = 1 {
    didSet { compositor.markDirty(self) }
  }

  @Signal
  public var position: Position<Float> = .zero {
    didSet { compositor.markDirty(self) }
  }

  @Signal
  public var size: Size<Float> = .zero {
    didSet { compositor.markDirty(self) }
  }

  @Signal
  public var scale: Float = 1 {
    didSet { compositor.markDirty(self) }
  }

  @Signal
  public var affine: Float = 1 {
    didSet { compositor.markDirty(self) }
  }

  @Signal
  public var brush: Brush? = nil {
    didSet { compositor.markDirty(self) }
  }

  @Signal
  public var cornerRadius: Float = 0 {
    didSet { compositor.markDirty(self) }
  }

  @Signal
  public var cornerDegree: Float = 4 {
    didSet { compositor.markDirty(self) }
  }

  @Signal
  public var shouldRasterize: Bool = false {
    didSet {
      // fuckk
      // TODO: when isRasterizationRoot changed
      compositor.markDirty(self)
    }
  }

  // MARK: Compositor private

  package var isRasterizationRoot: Bool { _isRasterizationRoot.value }
  private lazy var _isRasterizationRoot: Computed<Bool> = Computed { [self] in
    shouldRasterize || (opacity != 1 && opacity != 0)
    // we can actually keep the rasterized texture for a while for fade animation
  }

  // i probably need to do some macro for this kind of thing
  public var absolutePosition: Position<Float> { _absolutePosition.value }
  private lazy var _absolutePosition: Computed<Position<Float>> = Computed { [self] in
    (self.parent?.absolutePosition ?? .zero) + self.position
  }

  public var rootRelativePosition: Position<Float> { _rootRelativePosition.value }
  private lazy var _rootRelativePosition: Computed<Position<Float>> = Computed { [self] in
    (self.rasterizationRoot?.absolutePosition ?? .zero) + self.position
  }

  // public var accumulatedAffine: Position<Float> { _accumulatedAffine.value }
  var rasterizationRoot: Layer? { _rasterizationRoot.value }
  private lazy var _rasterizationRoot: Computed<Layer?> = Computed { [self] in
    if let parent {
      if parent.isRasterizationRoot {
        parent
      } else {
        parent.rasterizationRoot
      }
    } else {
      nil
    }
  }

  /// TODO: Rect that contains all children
  public var boundingRect: Rect { _boundingRect.value }
  private lazy var _boundingRect: Computed<Rect> = Computed { [self] in
    Rect(topLeft: position, size: size)
  }

}
