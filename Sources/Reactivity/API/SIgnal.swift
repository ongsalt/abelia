@propertyWrapper
public final class Signal<T> {
    let node: Node = Node(label: String(describing: Signal<T>.self))

    public var value: T {
        get {
            TrackingContext.current?.reportRead(node)
            return self._value
        }
        set {
            if Self.isChanged(self._value, newValue) {
                self._value = newValue
                node.markDirty()
            }
        }
    }

    var _value: T

    public init(_ value: T) {
        self._value = value
    }

    static func isChanged(_ lhs: borrowing T, _ rhs: borrowing T) -> Bool {
        true
    }

    // property wrapper shi
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
    static func isChanged(_ lhs: borrowing T, _ rhs: borrowing T) -> Bool {
        lhs != rhs
    }
}
