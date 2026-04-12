protocol View: ~Copyable {

}

protocol Component: View {
    associatedtype Body: View

    // @ViewBuilder
    var body: Body { get }
}

// those inherit view should manage it own backing element
// provide macro for auto conforming and generate constructor? also markshit as state?
struct Text: View {
    // @Props
    // var text: String

    var text: String {
        self._text.value
    }

    // generated
    let _text: ReadOnlyBinding<String>
    init(_ text: @escaping @autoclosure () -> String) {
        self._text = ReadOnlyBinding(getter: text)
    }
}

struct Container: View {
    let children: [any View]

    init(@ViewBuilder body: () -> [any View]) {
        children = body()
    }
}

struct Shit: Component {
    let count = Signal(0)

    var body: some View {
        Container {
            Container {
                Text("Hello")
            }

            Text("count \(count.value)")
        }
    }
}

@resultBuilder
struct ViewBuilder {
    typealias Component = View

    // public static func buildBlock() -> [Component] {
    //     []
    // }

    // just in case we need this (if block?)
    public static func buildBlock(_ components: Component...) -> [Component] {
        components
    }
}

// @resultBuilder
// struct HOFViewBuilder {
//     typealias Component = View

//     // TODO: generics
//     public static func buildExpression<T>(_ expression: @autoclosure @escaping () -> T) -> () -> T {
//         expression
//     }

//     public static func buildBlock() -> () -> [Component] {
//         { [] }
//     }

//     // just in case we need this (if block?)
//     public static func buildBlock(_ components: (() -> Component)...) -> () -> [Component] {
//         {
//             components.map { $0() }
//         }
//     }
// }
