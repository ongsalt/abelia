// import Composition
// import Foundation
// import UI

// @Autobind
// class Counter: Component {
//     @State
//     var count = 0

//     var body: some View {
//         Text("count: \(self.count)")
//     }

//     init() {
//         Task { [self] in
//             while true {
//                 try await Task.sleep(for: .seconds(1))
//                 self.count += 1
//             }
//         }
//     }
// }

// @MainActor
// // @Autobind2
// // we need to put @MainActor in generated code too
// // maybe we can explicitly told the engine: which will be updated?
// func CounterFr() -> some View {
//     @State
//     var count = 0

//     return Container {
//         Text("count: \(count)")

//         Button(onClick: { count += 1 }) {
//             Text("increment")
//         }
//         // .padding(12)
//     }
// }

// @MainActor
// func Button(
//     onClick: @escaping () -> Void = {},
//     @ViewBuilder contents: () -> some View
// ) -> some View {

//     return Container {
//         contents()
//     }
// }

// class TransientComponent: Component {
//     var body: some View {
//         Text("hehe")
//     }

//     deinit {
//         print("----------Done")
//     }
// }

// func drop<T>(_ value: consuming T) {}

// @Autobind
// struct App: Component {
//     var body: some View {
//         Text("sdfnhudki")
//         Counter()
//         TransientComponent()
//     }
// }

// @MainActor
// func uiMain() {
//     let app = App()
//     let b = app.body

//     Task { [b] in
//         try await Task.sleep(for: .seconds(3))
//         // print(Swift._getRetainCount(b))
//         drop(b)
//     }

//     RunLoop.main.run()
// }
