/// Fast linear bump allocator allocating from a fixed raw buffer.
public struct BumpAllocator: AllocatorProtocol, ~Copyable {
    let buffer: UnsafeMutableRawBufferPointer
    var current: Int = 0

    public init(size: Int = 1024 * 1024 * 1) {
        buffer = .allocate(byteCount: size, alignment: 8)
    }

    public init(in buffer: UnsafeMutableRawBufferPointer) {
        self.buffer = buffer
    }

    /// Allocates typed uninitialized storage for `count` instances of `T`.
    public mutating func allocate<T>(_ type: T.Type, count: Int = 1) -> UnsafeMutablePointer<T> {
        _allocate(type, count: count, current: &current, buffer: buffer)
    }

    /// Resets allocator offset to zero.
    public mutating func reset() {
        current = 0
    }

    deinit {
        buffer.deallocate()
    }

    @_lifetime(&self)
    /// Creates a scoped child frame allocator.
    public mutating func createFrame() -> FrameAllocator {
        FrameAllocator(
            parent: &self, buffer: UnsafeMutableRawBufferPointer(rebasing: buffer[current...]))
    }
}

/// Scoped non-escaping frame allocator tied to a parent allocator's lifetime.
public struct FrameAllocator: ~Copyable, ~Escapable, AllocatorProtocol {
    let buffer: UnsafeMutableRawBufferPointer
    var current: Int = 0

    @_lifetime(&parent)
    init(parent: inout BumpAllocator, buffer: UnsafeMutableRawBufferPointer) {
        self.buffer = buffer
    }

    @_lifetime(&parent)
    init(parent: inout FrameAllocator, buffer: UnsafeMutableRawBufferPointer) {
        self.buffer = buffer
    }

    /// Allocates typed uninitialized storage for `count` instances of `T`.
    public mutating func allocate<T>(_ type: T.Type, count: Int = 1) -> UnsafeMutablePointer<T> {
        _allocate(T.self, count: count, current: &current, buffer: buffer)
    }

    @_lifetime(&self)
    /// Creates a nested child frame allocator.
    public mutating func createFrame() -> FrameAllocator {
        FrameAllocator(
            parent: &self,
            buffer: UnsafeMutableRawBufferPointer(rebasing: buffer[current...])
        )
    }
}

/// Common protocol for memory allocators.
public protocol AllocatorProtocol: ~Copyable, ~Escapable {
    // TODO: alignment
    mutating func allocate<T>(_ type: T.Type, count: Int) -> UnsafeMutablePointer<T>

    @_lifetime(&self)
    mutating func createFrame() -> FrameAllocator
}

extension AllocatorProtocol where Self: ~Copyable & ~Escapable {
    /// Allocates and mutates an instance of `T`.
    public mutating func allocate<T>(_ type: T.Type, mutate: (inout T) -> Void)
        -> UnsafeMutablePointer<T>
    {
        let ptr = allocate(T.self, count: 1)
        mutate(&ptr.pointee)
        return ptr
    }

    /// Allocates storage and writes a value of `T`.
    public mutating func write<T>(_ value: consuming T) -> UnsafeMutablePointer<T> {
        let ptr = allocate(T.self, count: 1)
        ptr.initialize(to: value)
        return ptr
    }

    /// Allocates and writes a null-terminated C string.
    public mutating func string(_ string: String) -> UnsafePointer<CChar> {
        string.utf8CString.withUnsafeBufferPointer { buffer in
            let ptr = allocate(CChar.self, count: buffer.count)
            ptr.initialize(from: buffer.baseAddress!, count: buffer.count)
            return UnsafePointer(ptr)
        }
    }

    /// Allocates and writes an array of C strings.
    public mutating func stringArray(_ array: [String]) -> UnsafePointer<UnsafePointer<CChar>?> {
        let ptrArray = allocate(UnsafePointer<CChar>?.self, count: array.count)

        for i in array.indices {
            ptrArray[i] = string(array[i])
        }

        return UnsafePointer(ptrArray)
    }

    /// Allocates and writes a contiguous buffer of elements.
    public mutating func array<T>(_ array: borrowing [T]) -> UnsafeMutableBufferPointer<T> {
        var first: UnsafeMutablePointer<T>?
        for index in array.indices {
            let ptr = write(array[index])
            if first == nil {
                first = ptr
            }
        }

        return UnsafeMutableBufferPointer(start: first, count: array.count)
    }
}

private func _allocate<T>(
    _ type: T.Type, count: Int = 1, current: inout Int, buffer: UnsafeMutableRawBufferPointer
) -> UnsafeMutablePointer<T> {
    let alignment = MemoryLayout<T>.alignment
    if current % alignment != 0 {
        current += alignment - (current % alignment)
    }

    if current + MemoryLayout<T>.stride * count >= buffer.count {
        fatalError("[BumpAllocator] Overflow.")
    }

    defer {
        current += MemoryLayout<T>.stride * count
    }

    let ptr = buffer.baseAddress! + current
    return UnsafeMutablePointer(OpaquePointer(ptr))
}
