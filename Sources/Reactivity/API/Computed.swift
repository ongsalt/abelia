@propertyWrapper
public final class Computed<T> {
    let node: Node = Node(label: String(describing: Computed<T>.self))

    public var value: T {
        TrackingContext.current?.reportRead(node)

        if !node.dirty {
            return _value!
        }
        node.clearDependencies()
        let deps = TrackingContext.track {
            _value = computation()
        }
        node.markClean()
        node.addDependency(deps)
        return _value!
    }

    var _value: T?
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
    public convenience init(wrappedValue: @autoclosure @escaping () -> T) {
        self.init(wrappedValue)
    }
}
