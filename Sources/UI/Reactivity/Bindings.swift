class ReadOnlyBinding<T> {
    var value: T {
        getter()
    }

    let getter: () -> T

    init(getter: @escaping () -> T) {
        self.getter = getter
    }

    init(_ implicitGetter: @autoclosure @escaping () -> T) {
        self.getter = implicitGetter
    }

    deinit {
        print("Deinit ReadOnlyBinding: \(value)")
    }
}

class Binding<T> {
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

    deinit {
        print("Deinit Binding: \(value)")
    }
}


typealias Bind<T> = ReadOnlyBinding<T>
typealias Writable<T> = Binding<T>