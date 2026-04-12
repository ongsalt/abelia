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

@Autobind
private class Test1: Component {
    let text: Bind<String>

    @State
    var count: Int = 8

    var a: Int

    var body: some View {
        // Text()
    }

    func shti() {  // ehhhhh
        count += 1
    }

    public func geh<T>(text: Bind<String>, hehe innernigga: T) async throws -> Int where T: AnyObject {
        self.a = 12

        return 1212
    }

    // mutating func setup() {
    //     self.a = 12
    // }

    // 1. hijack the construtor and use @Props macro to declare props -> we cant init other thing, and swift initialization rule gonna kill us
    // public init(text: @escaping @autoclosure () -> String, ) {
    //     // 'self' used before all stored properties are initializedSourceKit
    //     // we probably need to emulate this using macro
    //     self.$text = ReadOnlyBinding(getter: text)
    //     self.a = 12
    //     // self.setup()
    // }

    // 2. generate farbage default
    //  - fuck up didSet semantics
    //  - ARC retain gonna crash this
    // public init(text: @escaping @autoclosure () -> String, ) {
    //     // didset
    //     self.a = garbage()
    //     self.$text = ReadOnlyBinding(getter: text)

    //     self.setup()  // this will trigger didSet tho?
    // }

    // 3. manually

    // 4. old way, write this then the compiler generate a @autoclosure overload
    // this

    public init(text: Bind<String>) {
        self.a = 12
        self.text = text
    }
}
