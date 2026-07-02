package enum BindableStorage<T: Equatable> {
    case const(T)
    case getter(() -> T)
    case thunk(_Thunk<T>)

    var value: T {
        switch self {
        case .const(let value): value
        case .getter(let g): g()
        case .thunk(let thunk): thunk.value
        }
    }

    package var _dirty: Bool {
        switch self {
        case .const(_): false
        case .getter(_): false
        case .thunk(let t): t.dirty
        }
    }
}

@propertyWrapper
public struct Bindable<T: Equatable> {
    package var storage: BindableStorage<T>

    public var projectedValue: Self {
        // might use borrow/mutate
        get { self }
        set { self = newValue }
    }

    public var wrappedValue: T {
        get {
            storage.value
        }
        set {
            storage = .const(newValue)
        }
    }

    public init(wrappedValue: T) {
        storage = .const(wrappedValue)
    }

    public mutating func bind(_ expression: @autoclosure @escaping () -> T) {
        self.storage = .thunk(_Thunk(computation: expression))
    }

    public mutating func _bind(getter: @escaping () -> T) {
        self.storage = .getter(getter)
    }

    // must itself be a computed node. so we can report .dirty/need pull
    public mutating func bind(source: _Thunk<T>) {
        self.storage = .thunk(source)
    }
}

// TODO: ~escapable
struct BindableProjection {

}
