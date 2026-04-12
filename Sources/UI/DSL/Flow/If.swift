// class If: UI2 {
//     let condition: () -> Bool
//     let _then: () -> Void
//     let _else: (() -> Void)?

//     init(_ condition: @escaping @autoclosure () -> Bool, then: @escaping () -> Void, else _else: (() -> Void)? = nil) {
//         self.condition = condition
//         self._then = then
//         self._else = _else
//     }

//     func mount(context: Context2) {
//         Effect {
//             let show = self.condition()

//             untrack {
//                 if show {

//                 } else {

//                 }
//             }

//             // onDestroy {
//             //     root.unmount()
//             // }
//         }
//     }
// }