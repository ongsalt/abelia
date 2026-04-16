final class InputBuffer {
    let raw: RawGPUBuffer
    var offset: Int = 0

    init(state: VulkanState, size: Int = 4 * 1024 * 1024) {
        raw = RawGPUBuffer(allocator: state.allocator, device: state.device, size: size)
    }

    @inline(always)
    func write<BufferData>(_ data: [BufferData]) -> UInt64 {
        let current = offset
        offset += raw.write(data, offset: offset)
        return UInt64(current)
    }

    func reset() {
        offset = 0
    }
}

extension InputBuffer: Writable {
    @inline(always)
    func write<BufferData: ~Copyable>(data: consuming BufferData) -> UInt64 {
        let current = offset
        offset += raw.write(struct: consume data, offset: offset)
        return UInt64(current)
    }
}
