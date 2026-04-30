// @propertyWrapper
// public struct Props<T> {
//     var projectedValue: ReadOnlyBinding<T>?

//     var wrappedValue: T {
//         projectedValue!.value
//     }

//     init(externalName: String? = nil) {}

//     // default value
//     init(externalName: String? = nil, wrappedValue: T) {
//         self.projectedValue = ReadOnlyBinding { wrappedValue }
//     }
// }

@propertyWrapper
@MainActor
public struct State<T> {
    public var projectedValue: Signal<T>

    public var wrappedValue: T {
        get {
            projectedValue.value
        }
        set {
            projectedValue.value = newValue
        }
    }

    public init(wrappedValue: T) {
        self.projectedValue = Signal(wrappedValue)
    }
}

