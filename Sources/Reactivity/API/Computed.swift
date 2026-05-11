@propertyWrapper
public struct Computed<T> {
    @_spi(EmaInternal) public let node: Node = Node(label: String(describing: Computed<T>.self))

    public var value: T {
        _read {
            TrackingContext.current?.reportRead(node)

            if !node.dirty {
                yield storage.value!
                return
            }

            node.clearDependencies()
            let deps = TrackingContext.track {
                storage.value = computation()
            }
            node.markClean()
            node.addDependency(deps)
            yield storage.value!
        }
    }

    private var storage: Cell<T?> = Cell(nil)
    var computation: () -> T

    public init(_ computation: @escaping () -> T) {
        self.computation = computation
        node.markDirty()
    }

    // property wrapper shi
    public var wrappedValue: T {
        value
    }

    // this is cursed
    public init(wrappedValue: @autoclosure @escaping () -> T) {
        self.init(wrappedValue)
    }
}
extension Computed: CustomStringConvertible {
    public var description: String {
        "\(Computed<T>.self)(\(value))"
    }
}
private class Cell<T> {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
