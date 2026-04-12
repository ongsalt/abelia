protocol View: ~Copyable {

}

protocol Component: View {
    associatedtype Body: View

    // @ViewBuilder
    var body: Body { get }

    func setup()
}

extension View {
    func setup() {}
}

struct Fragment: View {
    let views: [any View]
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

// TODO: Variadic Generics
@resultBuilder
struct ViewBuilder {
    typealias Component = View

    // public static func buildBlock() -> [Component] {
    //     []
    // }

    // just in case we need this (if block?)
    public static func buildBlock(_ components: Component...) -> Fragment {
        Fragment(views: components)
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
