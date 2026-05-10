/// memory location is gauranteed for at least lifetime of this

public final class CArray<Element> {
    public let buffer: UnsafeMutableBufferPointer<Element>
    public var ptr: UnsafeMutablePointer<Element>? {
        buffer.baseAddress
    }

    public var count: UInt32 {
        UInt32(buffer.count)
    }

    public var readonly: UnsafePointer<Element>? {
        UnsafePointer(ptr)
    }

    public init(_ array: [Element]) {
        buffer = UnsafeMutableBufferPointer<Element>.allocate(capacity: array.count)
        _ = buffer.initialize(from: array)
    }

    public convenience init(move array: consuming [Element]) {
        self.init(array)
    }

    deinit {
        buffer.deinitialize()
    }
}
extension CArray: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Element

    public convenience init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}
