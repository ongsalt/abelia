@MainActor
public protocol View: ~Copyable {

}

public protocol Component: View {
    associatedtype Body: View

    @ViewBuilder
    var body: Body { get }
}

public struct Fragment: View {
    let views: [any View]

    static var empty: Fragment {
        Fragment(views: [])
    }
}

struct Shit: Component {
    let count = Signal(0)

    var body: some View {
        Container {
            Container {
                Text("String")
            }

            Text("count \(count.value)")
        }
    }
}

// TODO: Variadic Generics
@resultBuilder
@MainActor
public struct ViewBuilder {
    public static func buildBlock() -> Fragment {
        Fragment(views: [])
    }

    // just in case we need this (if block?)
    public static func buildBlock(_ components: View...) -> Fragment {
        for c in components {
            if let c = c as? any Component {
                c.body //  bruhhhh
            }
        }

        return Fragment(views: components)
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
