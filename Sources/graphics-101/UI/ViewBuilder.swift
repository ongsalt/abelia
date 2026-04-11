// @resultBuilder
// @MainActor
// struct ViewBuilder {
//     typealias Component = UIElement

//     // TODO: generics
//     public static func buildExpression<T>(_ expression: @autoclosure @escaping () -> T) -> () -> T {
//         expression
//     }

//     public static func buildBlock() -> () -> [UIElement] {
//         { [] }
//     }

//     public static func buildBlock(_ components: (() -> UIElement)...) -> () -> [UIElement] {
//         {
//             components.map { $0() }
//         }
//     }

//     public static func buildFinalResult(_ component: @escaping () -> [UIElement]) -> View {
//         View(_builder: component)
//     }

//     // public static func buildEither(first component: @escaping () -> [UIElement])
//     //     -> () -> UIElement
//     // {
//     //     component // wrap this with Component
//     // }

//     // public static func buildEither(second component: @escaping () -> [UIElement])
//     //     -> () -> UIElement
//     // {
//     //     component
//     // }
// }

// class View {
//     let builder: () -> [UIElement]

//     init(_builder: @escaping () -> [UIElement]) {
//         self.builder = _builder
//     }

//     init(@ViewBuilder _ builder: @escaping () -> [UIElement]) {
//         self.builder = builder
//     }

//     func build() -> [UIElement] {
//         builder()
//     }
// }

// extension ZStack {
//     convenience init(@ViewBuilder children: () -> View) {
//         self.init()
//         addChild(children())
//     }
// }


// @MainActor
// private struct What {
//     @ViewBuilder var a: View {
//         UIElement()
//     }
// }
