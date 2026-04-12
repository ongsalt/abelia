class If<Then: View, Else: View>: Component {
    let condition: Bind<Bool>
    let then: () -> Then
    let fallback: () -> Else

    init(
        _ condition: Bind<Bool>, @ViewBuilder then: @escaping () -> Then,
        @ViewBuilder else fallback: @escaping () -> Else = { Fragment.empty }
    ) {
        self.condition = condition
        self.then = then
        self.fallback = fallback
    }

    var body: some View {
        Container {
            
        }   
    }
    // let condition: () -> Bool
    // let _then: () -> Void
    // let _else: (() -> Void)?

    // init(_ condition: @escaping @autoclosure () -> Bool, then: @escaping () -> Void, else _else: (() -> Void)? = nil) {
    //     self.condition = condition
    //     self._then = then
    //     self._else = _else
    // }

    // func mount(context: Context2) {
    //     Effect {
    //         let show = self.condition()

    //         untrack {
    //             if show {

    //             } else {

    //             }
    //         }

    //         // onDestroy {
    //         //     root.unmount()
    //         // }
    //     }
    // }
}
