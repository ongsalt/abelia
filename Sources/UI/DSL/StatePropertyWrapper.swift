@propertyWrapper
struct Props<T> {
    var projectedValue: ReadOnlyBinding<T>?

    var wrappedValue: T {
        projectedValue!.value
    }

    init(externalName: String? = nil) {}

    // default value
    init(externalName: String? = nil, wrappedValue: T) {
        self.projectedValue = ReadOnlyBinding { wrappedValue }
    }
}

@propertyWrapper
struct State<T> {
    var projectedValue: Signal<T>

    var wrappedValue: T {
        get {
            projectedValue.value
        }
        set {
            projectedValue.value = newValue
        }
    }

    init(wrappedValue: T) {
        self.projectedValue = Signal(wrappedValue)
    }
}

@Component
private struct Test1 {
    @Props
    var text: String

    @State
    var count: Int = 8

    var body: some View {
        Text("fty \(count)")
    }

    mutating func shti() {  // ehhhhh
        count += 1
    }
}
