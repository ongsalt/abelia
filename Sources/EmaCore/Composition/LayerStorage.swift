import CVulkan  // for LayerStorageNode

class LayerStorage {
  private let buffer: UnsafeMutableBufferPointer<LayerStorageNode>
  private var recycledSlots: Set<UInt64> = []
  private var currentIndex: UInt64 = 0
  // [layer.id : slotIndex]
  private var indexMap: [ObjectIdentifier: UInt64] = [:]

  init(mutating buffer: UnsafeMutableBufferPointer<LayerStorageNode>) {
    self.buffer = buffer
  }

  convenience init(_ buffer: GPUBuffer) {
    self.init(mutating: buffer.buffer.assumingMemoryBound(to: LayerStorageNode.self))
  }

  func index(of layer: borrowing Layer) -> UInt64 {
    index(of: layer.id)
  }

  func index(of layerId: ObjectIdentifier) -> UInt64 {
    var index = indexMap[layerId]
    if index == nil {
      if let availableSlot = recycledSlots.first {  // well its random index, but who care
        index = availableSlot
      } else {
        index = currentIndex
        currentIndex += 1
      }
      indexMap[layerId] = index
    }

    return index!
  }

  func remove(_ layer: borrowing Layer) {
    remove(layer.id)
  }

  func remove(_ layerId: ObjectIdentifier) {
    if let index = indexMap[layerId] {
      indexMap[layerId] = nil
      recycledSlots.insert(index)
    }
  }

  func update(_ layer: borrowing Layer) {
    let index = index(of: layer)
    buffer[Int(index)] = layer.asStorageNode
  }

  func set(_ data: LayerStorageNode, at index: Int) {
    buffer[index] = data
  }
}

extension Layer {
  var asStorageNode: LayerStorageNode {
    LayerStorageNode()
  }
}

// do i need to define this in c???
