protocol Writable: ~Copyable {
    // @inline(always)
    mutating func write<BufferData: ~Copyable>(data: consuming BufferData) -> UInt64
}

extension Writable where Self: ~Copyable {
    // @inline(always)
    mutating func write<let count: Int, BufferData>(
        inlined array: consuming InlineArray<count, BufferData>
    )
        -> UInt64
    {
        self.write(data: array)
    }
}

struct BufferWriter: ~Copyable, Writable {
    let raw: UnsafeMutableRawBufferPointer
    var offset: UInt64

    init(_ buffer: UnsafeMutableRawBufferPointer, at position: UInt64 = 0) {
        self.raw = buffer
        self.offset = position
    }

    @inline(always)
    mutating func write<BufferData: ~Copyable>(data: consuming BufferData) -> UInt64 {
        self.raw.baseAddress!.assumingMemoryBound(to: BufferData.self).pointee = consume data
        let size = UInt64(MemoryLayout<BufferData>.size)
        offset += size
        return UInt64(MemoryLayout<BufferData>.size)
    }

    mutating func reset() {
        offset = 0
    }
}
