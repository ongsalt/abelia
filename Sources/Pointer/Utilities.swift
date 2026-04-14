public func createZeroedStruct<T>(of: T.Type) -> T {
    // TODO: make this on stack

    let raw = UnsafeMutableRawBufferPointer.allocate(
        byteCount: MemoryLayout<T>.size,
        alignment: MemoryLayout<T>.alignment
    )
    raw.initializeMemory(as: UInt8.self, repeating: 0)
    defer {
        raw.deallocate()
    }

    let ptr = UnsafePointer<T>(OpaquePointer(raw.baseAddress!))

    return ptr.pointee
}


public func expect<T>(_ value: T?, _ message: String) -> T {
    if value == nil {
        fatalError(message)
    }
    return value!
}

