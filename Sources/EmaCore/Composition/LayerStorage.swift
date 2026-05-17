import CVulkan  // for LayerStorageNode

private struct PassId: Hashable {
  let layerId: ObjectIdentifier
  let passIndex: UInt
}

class LayerStorage {
  private let buffer: UnsafeMutableBufferPointer<LayerStorageNode>
  private var recycledSlots: Set<UInt64> = []
  private var currentIndex: UInt64 = 0
  // [(layer.id, passIndex) : slotIndex]
  private var indexMap: [PassId: UInt64] = [:]

  init(mutating buffer: UnsafeMutableBufferPointer<LayerStorageNode>) {
    self.buffer = buffer
  }

  convenience init(_ buffer: GPUBuffer) {
    self.init(mutating: buffer.buffer.assumingMemoryBound(to: LayerStorageNode.self))
  }

  func index(of layer: borrowing Layer) -> UInt64 {
    index(of: layer.id)
  }

  func index(of layerId: ObjectIdentifier, passIndex: UInt = 0) -> UInt64 {
    let id = PassId(layerId: layerId, passIndex: passIndex)
    var index = indexMap[id]
    if index == nil {
      if let availableSlot = recycledSlots.popFirst() {  // well its random index, but who care
        index = availableSlot
      } else {
        index = currentIndex
        currentIndex += 1
      }
      indexMap[id] = index
    }

    return index!
  }

  func remove(_ layer: borrowing Layer) {
    // remove(layer.id)
  }

  func remove(_ layerId: ObjectIdentifier, passIndex: UInt) {
    let id = PassId(layerId: layerId, passIndex: passIndex)
    if let index = indexMap[id] {
      indexMap[id] = nil
      recycledSlots.insert(index)
    }
  }

  @MainActor
  // TODO: compute storage node when batching
  func update(_ layer: borrowing Layer) {
    let index = index(of: layer)
    buffer[Int(index)] = layer.asStorageNode
    print(buffer[Int(index)])
  }

  func set(_ data: LayerStorageNode, at index: Int) {
    buffer[index] = data
  }
}

extension Layer {
  // backdrop effect make 1 layer corresponds to more than 1 Node
  var asStorageNode: LayerStorageNode {
    with(LayerStorageNode()) {
      $0.centerX = self.position.x - size.x / 2
      $0.centerY = self.position.y - size.y / 2
      $0.shapeKind = .roundRect
      $0.shape.roundedRect = .init(
        halfWidth: size.x / 2, halfHeight: size.y / 2, cornerRadius: self.cornerRadius,
        cornerDegree: self.cornerDegree)

      switch brush {
      case .solid(let color):
        $0.brushKind = .solid
        $0.brush.solid.color = color.asTuple
      case .image(let image, let ninegrid, let crop):
        $0.brushKind = .texture
        $0.brush.texture.textureIndex = image.textureIndex
        $0.brush.texture.crop = crop.asTuple
        $0.brush.texture.ninegrid = ninegrid.asTuple
      // case .effect(let filters):
      //   filters.
      default:
        $0.brushKind = .solid
      }
      $0.opacity = self.opacity
    }
  }
}

// do i need to define this in c???
