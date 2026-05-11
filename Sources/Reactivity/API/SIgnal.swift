@propertyWrapper
public struct Signal<T> {
    let node: Node = Node(label: String(describing: Signal<T>.self))

    public var value: T {
        _read {
            TrackingContext.current?.reportRead(node)
            yield self._value
        }
        _modify {
            yield &self._value
            node.markChildrenDirty()
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
        _read {
            yield value
        }
        _modify {
            yield &value
        }
    }

    public init(wrappedValue: T) {
        self.init(wrappedValue)
    }
}

extension Signal where T: Equatable {
    public var value: T {
        _read {
            TrackingContext.current?.reportRead(node)
            yield self._value
        }
        _modify {
            var newValue = self._value
            yield &newValue
            if self._value != newValue {
                self._value = newValue
                node.markChildrenDirty()
            }
        }
    }
}

extension Signal: CustomStringConvertible {
    public var description: String {
        "\(Signal<T>.self)(\(value))"
    }
}
