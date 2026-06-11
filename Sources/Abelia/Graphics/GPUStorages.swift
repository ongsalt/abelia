import CShim
import Vulkan

class GPUStorage<T> {
    private let vmaBuffer: VmaBuffer
    var buffer: Buffer {
        vmaBuffer.buffer
    }

    var bufferPointer: UnsafeMutableBufferPointer<T> {
        vmaBuffer.bufferPointer!.assumingMemoryBound(to: T.self)
    }

    init(context: borrowing SurfaceContext, count: UInt64 = 16 * 1024) throws(Vulkan.Result) {
        let size = count * UInt64(MemoryLayout<T>.size)
        self.vmaBuffer = try context.createVmaBuffer(size: size)
    }
}

// TODO: buffer resizing
class RenderNodeStorage: GPUStorage<CShim.RenderNode> {
    private var recycledSlots: Set<Int> = []
    private var currentIndex: Int = 0
    // [nodeId : slotIndex]
    private var indexMap: [Int: Int] = [:]

    public func update(node: borrowing RenderNode, shapeGroupStorage: ShapeGroupStorage) {
        let index = index(of: node)
        node.write(
            to: &bufferPointer[index],
            identity: UInt(bitPattern: node.id),
            shapeGroupStorage: shapeGroupStorage
        )
    }

    func index(of node: borrowing RenderNode) -> Int {
        index(objectId: node.id)
    }

    func index(objectId: ObjectIdentifier) -> Int {
        let id = Int(bitPattern: objectId)
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
}

class ShapeGroupStorage: GPUStorage<CShim.ShapeMergingInstruction> {
    // func update(nodeOf group: borrowing some ShapeGroupOwner) {
    // }
}

class DrawListStorage: GPUStorage<UInt32> {
    func write(_ nodes: borrowing [RenderNode.ID], renderNodeStorage: RenderNodeStorage) {
        for (index, nodeId) in nodes.enumerated() {
            let nodeIndex = renderNodeStorage.index(objectId: nodeId)
            self.bufferPointer[index] = UInt32(nodeIndex)
        }
    }
}
