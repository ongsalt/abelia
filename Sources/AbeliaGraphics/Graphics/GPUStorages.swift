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

    func write(_ data: borrowing Span<T>, at offset: Int = 0) {
        data.withUnsafeBufferPointer { data in
            let raw = UnsafeRawBufferPointer(data)
            raw.copyBytes(to: self.bufferPointer.extracting(offset...))
        }
    }

    private(set) var offset: Int = 0
    func append(_ data: consuming T) {
        self.bufferPointer[offset] = data
        offset += 1
    }

    func append(_ span: borrowing Span<T>) {
        span.withUnsafeBufferPointer { span in
            let raw = UnsafeRawBufferPointer(span)
            raw.copyBytes(to: self.bufferPointer.extracting(offset...))
        }
        offset += span.count
    }

    func resetOffset() {
        offset = 0
    }

}

// TODO: buffer resizing
class RenderNodeStorage: GPUStorage<CShim.RenderNode> {
}

// claude wrote reusing part
class ShapeGroupStorage: GPUStorage<CShim.ShapeMergingEntry> {
}

class DrawListStorage: GPUStorage<DrawListItem> {
}
