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

    init(context: borrowing DeviceContext, count: UInt64 = 16 * 1024) throws(Vulkan.Result) {
        let size = count * UInt64(MemoryLayout<T>.size)
        self.vmaBuffer = try context.createVmaBuffer(size: size)
    }
}

// TODO: buffer resizing
class RenderNodeStorage: GPUStorage<CShim.RenderNode> {
    private var recycledSlots: Set<Int> = []
    private var currentIndex: Int = 0
    private var indexMap: [Int: Int] = [:]

    public func update(node: borrowing RenderNode, shapeGroupStorage: ShapeGroupStorage) {
        let index = index(of: node)
        node.write(
            to: &bufferPointer[index],
            identity: node.id,
            shapeGroupStorage: shapeGroupStorage
        )
    }

    func print(offset: Int, count: Int) {
        Swift.print("\(Self.self)")
        // for i in offset..<offset + count {
        //     let data = bufferPointer[i]
        //     if data.kind == .push {
        //         Swift.print("  [\(i)] shapeKind=\(data.data.shape.shapeKind.rawValue) offset=\(data.data.shape.offset)")
        //     } else {
        //         Swift.print("  [\(i)] merge=\(data.data.merge.mode.rawValue) smoothing=\(data.data.merge.smoothing)")
        //     }
        // }
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

// claude wrote reusing part
class ShapeGroupStorage: GPUStorage<CShim.ShapeMergingEntry> {
    // owner -> (offset, length). length == used == capacity (exact-fit).
    private var allocatedRegions: [ObjectIdentifier: (offset: Int, length: Int)] = [:]
    // Free blocks, kept sorted by offset and coalesced. No two entries are adjacent.
    private var freeList: [(offset: Int, length: Int)] = []
    // Bump cursor: everything at >= lastPosition is untouched space.
    private var lastPosition: Int = 0

    func update(ownerIdentity: ObjectIdentifier, data: [ShapeMergingInstruction]) -> Int? {
        guard !data.isEmpty else {
            delete(ownerIdentity: ownerIdentity)
            return nil
        }
        let count = data.count

        if let region = allocatedRegions[ownerIdentity] {
            if count == region.length {
                write(data, at: region.offset)  // same size: rewrite in place
                return region.offset
            }
            if count < region.length {  // shrink in place, free the tail
                write(data, at: region.offset)
                recycle(offset: region.offset + count, length: region.length - count)
                allocatedRegions[ownerIdentity] = (region.offset, count)
                return region.offset
            }
            // grow: doesn't fit -> free old slot and relocate (offset CHANGES here)
            recycle(offset: region.offset, length: region.length)
        }

        let offset = allocate(count)
        allocatedRegions[ownerIdentity] = (offset, count)
        write(data, at: offset)
        return offset
    }

    func print(offset: Int, count: Int) {
        Swift.print("\(Self.self)")
        for i in offset..<offset + count {
            let data = bufferPointer[i]
            if data.kind == .push {
                Swift.print(
                    "  [\(i)] shapeKind=\(data.data.shape.shapeKind.rawValue) offset=\(data.data.shape.offset)"
                )
            } else {
                Swift.print(
                    "  [\(i)] merge=\(data.data.merge.mode.rawValue) smoothing=\(data.data.merge.smoothing)"
                )
            }
        }
    }

    func delete(ownerIdentity: ObjectIdentifier) {
        guard let region = allocatedRegions.removeValue(forKey: ownerIdentity) else { return }
        recycle(offset: region.offset, length: region.length)
    }

    // MARK: - internals

    private func write(_ data: borrowing [ShapeMergingInstruction], at offset: Int) {
        let region = bufferPointer.extracting(offset..<offset + data.count)
        for (i, instruction) in data.enumerated() {
            region[i] = instruction.c
        }
    }

    /// Best-fit over the free list, falling back to bumping the cursor.
    private func allocate(_ length: Int) -> Int {
        var best: Int? = nil
        for (i, block) in freeList.enumerated() where block.length >= length {
            if best == nil || block.length < freeList[best!].length { best = i }
        }
        if let i = best {
            let block = freeList[i]
            if block.length == length {
                freeList.remove(at: i)
            } else {
                freeList[i] = (block.offset + length, block.length - length)  // carve front
            }
            return block.offset
        }
        let offset = lastPosition
        lastPosition += length
        precondition(lastPosition <= bufferPointer.count, "ShapeGroupStorage out of space")
        return offset
    }

    /// Return a block to the free list, coalescing neighbors. If the merged
    /// block touches the cursor, hand it back to the cursor instead of storing it.
    private func recycle(offset: Int, length: Int) {
        var merged = (offset: offset, length: length)
        var idx = freeList.firstIndex { $0.offset > offset } ?? freeList.count

        if idx > 0 {  // merge with previous
            let prev = freeList[idx - 1]
            if prev.offset + prev.length == merged.offset {
                merged = (prev.offset, prev.length + merged.length)
                freeList.remove(at: idx - 1)
                idx -= 1
            }
        }
        if idx < freeList.count {  // merge with next
            let next = freeList[idx]
            if merged.offset + merged.length == next.offset {
                merged = (merged.offset, merged.length + next.length)
                freeList.remove(at: idx)
            }
        }

        if merged.offset + merged.length == lastPosition {
            lastPosition = merged.offset  // reclaim tail into the cursor
            while let last = freeList.last, last.offset + last.length == lastPosition {
                lastPosition = last.offset
                freeList.removeLast()
            }
        } else {
            freeList.insert(merged, at: idx)
        }
    }
}

class DrawListStorage: GPUStorage<DrawListItem> {
    func write(
        _ nodes: [RenderNode], renderNodeStorage: RenderNodeStorage, seperateShadow: Bool = false
    ) -> Int {
        var index = 0
        if seperateShadow {
            for node in nodes {
                if node.shadowOpacity != 0 && node.shadowColor.alpha != 0 {
                    let nodeIndex = renderNodeStorage.index(objectId: node.id)
                    self.bufferPointer[index] = DrawListItem(
                        index: UInt32(nodeIndex), drawMode: .shadow)
                    index += 1
                }
            }
        }

        for node in nodes {
            let nodeIndex = renderNodeStorage.index(objectId: node.id)
            if !seperateShadow && node.shadowOpacity != 0 && node.shadowColor.alpha != 0 {
                self.bufferPointer[index] = DrawListItem(
                    index: UInt32(nodeIndex), drawMode: .shadow)
                index += 1
            }

            self.bufferPointer[index] = DrawListItem(index: UInt32(nodeIndex), drawMode: .fill)
            index += 1

            if node.borderWidth != 0 {
                self.bufferPointer[index] = DrawListItem(
                    index: UInt32(nodeIndex), drawMode: .stroke)
                index += 1
            }
        }
        return index
    }
}
