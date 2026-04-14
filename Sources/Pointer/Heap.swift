// just put this onto heap
public class Heap<T> {
    public var value: T

    public init(_ value: T) {
        self.value = value
    }

    public func leak() {
        Unmanaged.passRetained(self)
    }
}
