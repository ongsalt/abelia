import Reactivity

public struct Prop<T> {
    var value: T {
        getter()
    }

    private var getter: () -> T

    init(getter: @escaping () -> T) {
        self.getter = getter
    }

    public static func `default`(_ value: T) -> Prop<T> {
        Prop(getter: { value })
    }

}
protocol Bindings<Value> {
    associatedtype Value
    var value: Value { get set }
}
extension Signal: Bindings<T> {}
public struct Bind<T>: Bindings {
    var value: T {
        get { getter() }
        set { setter(newValue) }
    }

    let getter: () -> T
    let setter: (T) -> Void

    init(getter: @escaping () -> T, setter: @escaping (T) -> Void) {
        self.getter = getter
        self.setter = setter
    }
}
