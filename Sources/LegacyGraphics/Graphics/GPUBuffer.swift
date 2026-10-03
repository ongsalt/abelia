import CShim
import Vulkan

class GPUBuffer<T> {
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
    @discardableResult
    func append(_ data: consuming T) -> Int {
        let index = offset
        self.bufferPointer[index] = data
        offset += 1
        return index
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

    func dump(range: Range<Int>? = nil) {
        let range = range ?? (0..<offset)

        Log.debug(.gpuStorage, "Dumping \(Self.self) in \(range):")
        for i in range {
            Log.debug(.gpuStorage, " - \(bufferPointer[i])")
        }
    }
}

// TODO: buffer resizing
typealias RenderNodeBuffer = GPUBuffer<CShim.RenderNode>

// claude wrote reusing part
typealias ShapeBuffer = GPUBuffer<CShim.ShapeMergingEntry>

typealias DrawListBuffer = GPUBuffer<DrawListItem>

// vertices for Shape.polygon
typealias PolygonVertexBuffer = GPUBuffer<SIMD2<Float>>

extension DrawListItem: @retroactive CustomStringConvertible {
    public var description: String {
        "DrawListItem(index: \(index), mode: \(drawMode.rawValue))"
    }
}

extension BrushKind: @retroactive CustomStringConvertible {
    public var description: String {
        "BrushKind(\(self.rawValue))"
    }
}

extension ShapeKind: @retroactive CustomStringConvertible {
    public var description: String {
        "ShapeKind(\(self.rawValue))"
    }
}


