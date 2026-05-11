import CVulkan  // for LayerStorageNode

class LayerStorage {
  private let buffer: UnsafeMutableBufferPointer<LayerStorageNode>
  private var recycledSlots: Set<UInt64> = []
  private var currentIndex: UInt64 = 0
  // [layer.id : slotIndex]
  private var indexMap: [ObjectIdentifier: UInt64] = [:]

  init(in buffer: UnsafeMutableBufferPointer<LayerStorageNode>) {
    self.buffer = buffer
  }

  func index(of layer: borrowing Layer) -> UInt64 {
    var index = indexMap[layer.id]
    if index == nil {
      if let availableSlot = recycledSlots.first {  // well its random index, but who care
        index = availableSlot
      } else {
        index = currentIndex
        currentIndex += 1
      }
      indexMap[layer.id] = index
    }

    return index!
  }

  func remove(_ layer: borrowing Layer) {
    if let index = indexMap[layer.id] {
      indexMap[layer.id] = nil
      recycledSlots.insert(index)
    }
  }

  func update(_ layer: borrowing Layer) {
    let index = index(of: layer)
    buffer[Int(index)] = layer.asStorageNode
    
  }
}

extension Layer {
  var asStorageNode: LayerStorageNode {
    LayerStorageNode()
  }
}

// do i need to define this in c???
