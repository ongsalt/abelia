@propertyWrapper
public final class Signal<T> {
    let node: Node = Node(label: String(describing: Signal<T>.self))

    public var value: T {
        get {
            TrackingContext.current?.reportRead(node)
            return self._value
        }
        set {
            self._value = newValue
            node.markDirty()
        }
    }

    private var _value: T

    public init(_ value: T) {
        self._value = value
    }

    // property wrapper shi
    // this fucked up where T: Equatable
    // i probably need a custom property wrapper macro
    public var wrappedValue: T {
        get {
            value
        }
        set {
            value = newValue
        }
    }

    public convenience init(wrappedValue: T) {
        self.init(wrappedValue)
    }
}

extension Signal where T: Equatable {
    public var value: T {
        get {
            TrackingContext.current?.reportRead(node)
            return self._value
        }
        set {
            if self._value != newValue {
                self._value = newValue
                node.markDirty()
            }
        }
    }
}

extension Signal: CustomStringConvertible {
    public var description: String {
        "\(Signal<T>.self)(\(value))"
    }
}
