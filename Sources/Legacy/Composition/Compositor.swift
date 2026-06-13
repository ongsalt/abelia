import CVulkan

import Dispatch

// public api @MainActor???
import SwiftBlend2D

import Synchronization

@MainActor
public class Compositor {
  private(set) public var root: RootLayer!
  private let renderer: Renderer

  var dirtyLayers: [Layer] = []
  var dirtyLayerIds: Set<ObjectIdentifier> = []

  public var animationFrameCallback: (() -> Void)?

  public init(surface: Surface, device: GraphicsDevice) {
    self.renderer = Renderer(surface: surface, device: device)
    self.root = RootLayer(compositor: self)
    renderer.compositor = self
  }

  public func resize(to size: Size<UInt32>) {
    self.markDirty(root, shouldRecreateSwapchain: true)
  }

  func markDirty(_ layer: Layer, accumulated: Bool = false, shouldRecreateSwapchain: Bool = false) {
    let (inserted, _) = dirtyLayerIds.insert(layer.id)
    if inserted {
      dirtyLayers.append(layer)
    }

    if accumulated {
      for c in layer.children {
        markDirty(c, accumulated: true)
      }
    }

    // tell renderer we need rerender
    renderer.markRerenderNeeded(shouldRecreateSwapchain: shouldRecreateSwapchain)
  }

  /// actually flush everything and give the information needed for render
  func onRendererFrame() -> (
    dirtyRects: [Rect], dirtyLayerStorageNodes: [ObjectIdentifier: [LayerStorageNode]],
    batches: [Batch]
  ) {
    animationFrameCallback?()

    let dirtyLayers = dirtyLayers
    self.dirtyLayers = []
    dirtyLayerIds = []
    let batches = createBatches(dirtyLayers: dirtyLayers, root: self.root)

    var dirtyLayerStorageNodes: [ObjectIdentifier: [LayerStorageNode]] = [:]
    for layer in dirtyLayers {
      dirtyLayerStorageNodes[layer.id] = [layer.asStorageNode]
    }

    return ([], dirtyLayerStorageNodes, batches)
  }

  public func createImage(from blImage: BLImage) -> Image {
    let texture = renderer.textureRegistry.createTexture(from: blImage, usages: .static)

    return Image(texture: texture)
  }

  public func createLayer() -> Layer {
    Layer(compositor: self)
  }
}
public class RootLayer: Layer, @unchecked Sendable {

}
