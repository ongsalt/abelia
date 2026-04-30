// @MainActor
// public protocol View: ~Copyable {

// }

// public struct Fragment: View {
//     let views: [any View]

//     static var empty: Fragment {
//         Fragment(views: [])
//     }

//     // public func evaluate() {
//     //     for v in self.views {
//     //         v.evaluate()
//     //     }
//     // }
// }

public typealias View = LayoutNode
public typealias Body = [LayoutNode]

// struct Shit: Component {
//     let count = Signal(0)

//     var body: some View {
//         Container {
//             Container {
//                 Text("String")
//             }

//             Text("count \(count.value)")
//         }
//     }
// }

// TODO: Variadic Generics
@resultBuilder
@MainActor
public struct ViewBuilder {
    public static func buildBlock() -> Body {
        []
    }

    // just in case we need this (if block?)
    public static func buildBlock(_ components: View...) -> Body {
        return components
    }
}
