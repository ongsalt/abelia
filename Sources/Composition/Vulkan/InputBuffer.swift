class InputBuffer {
    let raw: RawGPUBuffer
    var offset: Int = 0

    init(state: VulkanState, size: Int = 4 * 1024 * 1024) {
        raw = RawGPUBuffer(allocator: state.allocator, device: state.device, size: size)
    }

    func write<BufferData>(_ data: [BufferData]) -> UInt64 {
        let current = offset
        offset += raw.write(data, offset: offset)
        return UInt64(current)
    }

    // func write<BufferData>(_ data: UnsafeBufferPointer<BufferData>, offset: Int = 0) -> Int {

    // }

    func reset() {
        offset = 0
    }

    // func move(_ amount: Int) {
    //     offset += amount
    // }
}
