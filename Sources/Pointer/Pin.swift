public class Pin<T> {
    public let buffer: UnsafeMutableBufferPointer<T>
    public var readonly: UnsafePointer<T> {
        UnsafePointer(buffer.baseAddress!)
    }

    public var count: UInt32 {
        UInt32(buffer.count)
    }

    public init(_ data: [T]) {
        buffer = UnsafeMutableBufferPointer.allocate(capacity: data.count)
        buffer.initialize(from: data)
    }

    deinit {
        buffer.deinitialize()
    }
}
