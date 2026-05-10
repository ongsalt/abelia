public struct Box<T>: ~Copyable {
    public let mut: UnsafeMutablePointer<T>
    public var ptr: UnsafePointer<T> {
        UnsafePointer(mut)
    }
    public var opaque: OpaquePointer {
        OpaquePointer(mut)
    }

    public var raw: UnsafeRawPointer {
        UnsafeRawPointer(mut)
    }

    public var rawMut: UnsafeMutableRawPointer {
        UnsafeMutableRawPointer(mut)
    }

    public init(_ value: consuming T, mutate: ((inout T) -> Void)? = nil) {
        var value = value
        if let mutate {
            mutate(&value)
        }
        mut = UnsafeMutablePointer.allocate(capacity: 1)
        mut.initialize(to: value)
    }

    public init(pointingTo ptr: UnsafeMutablePointer<T>) {
        self.mut = ptr
    }

    public init<K>(optional value: K) where T == K? {
        self.init(value)
    }

    public init(zeroedStructOf type: T.Type) {
        self.init(createZeroedStruct(of: type))
    }

    public var pointee: T {
        _read {
            yield mut.pointee
        }
        _modify {
            yield &mut.pointee
        }
    }
    public var value: T {
        _read {
            yield mut.pointee
        }
        _modify {
            yield &mut.pointee
        }
    }

    public mutating func mutate(_ block: (inout T) -> Void) {
        block(&pointee)
    }

    deinit {
        mut.deinitialize(count: 1)
        mut.deallocate()
    }
}
