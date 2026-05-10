import Reactivity

public struct Prop<T> {
    var value: T {
        getter()
    }

    var getter: () -> T

    init(getter: @escaping () -> T) {
        self.getter = getter
    }
}

public struct FnBindings<T>: Bindings {
    var value: T {
        get { getter() }
        set { setter(newValue) }
    }

    let getter: () -> T
    let setter: @escaping (T) -> Void

    init(getter: @escaping () -> T, setter: @escaping (T) -> Void) {
        self.getter = getter
        self.setter = setter
    }
}

protocol Bindings<Value> {
    typealias Value
    var value: Value { get set }
}

extension Signal: Bindings<T> {}

// TODO: make macro read this
public typealias Bind<T> = Prop<T>
