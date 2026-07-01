private func api() {
    // qt shit
    Box {
    }.width(12)

}

// copied from PanGui, need to see clay
enum Size: Sendable {
    /// [0, 1] fraction of parent
    case fraction(Float)
    case fit(fractionOfSelf: Float)
    case fill(weight: Float)
    case pixels(Float)

    // depends on other axis
    case aspectRatio(Float)
}

extension Size {
    static let fill = Self.fill(weight: 1)
    static let fit = Self.fit(fractionOfSelf: 1)
}

class LayoutComponent {
    @Bindable
    var a: Float = 5

    func width(_ value: @autoclosure @escaping () -> Float) {
        $a.bind(to: value)
    }
}

// make this property wrapper maybe
private enum BindableStorage<T> {
    case const(T)
    case getter(() -> T)
    case source(any Source<T>)

    var value: T {
        switch self {
        case .const(let value): value
        case .getter(let g): g()
        case .source(let source): source.value
        }
    }
}

@propertyWrapper
public struct Bindable<T> {
    private var storage: BindableStorage<T>

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
        self.storage = .getter(expression)
    }

    public mutating func bind(to computation: @escaping () -> T) {
        self.storage = .getter(computation)
    }

    public mutating func bind(to source: any Source<T>) {
        self.storage = .source(source)
    }
}

final class Box: LayoutComponent {
    init(children: () -> Void) {}
    init(children: (Self) -> Void) {}
}
