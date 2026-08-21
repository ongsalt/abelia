class BumpAllocator {
    let buffer: UnsafeMutableRawBufferPointer
    var current: Int = 0

    init(size: Int = 1024 * 1024 * 8) {
        buffer = .allocate(byteCount: size, alignment: 8)
    }

    func allocate<T>(_ type: T.Type) -> UnsafeMutablePointer<T> {
        let alignment = MemoryLayout<T>.alignment
        if current % alignment != 0 {
            current += alignment - (current % alignment)
        }
        defer {
            current += MemoryLayout<T>.size
        }

        let ptr = buffer.baseAddress! + current
        return UnsafeMutablePointer(ptr)
    }

    /// Make sure there are no dangling ref
    func reset() {
        current = 0
    }

    deinit {
        buffer.deallocate()
    }

    func createSubAllocator() -> SubAllocator {
        SubAllocator(parent: self, start: current)
    }

    struct SubAllocator: ~Copyable {
        let parent: BumpAllocator
        let start: Int

        func allocate<T>(_ type: T.Type) -> UnsafeMutablePointer<T> {
            parent.allocate(type)
        }

        deinit {
            parent.current = start
        }
    }
}
