import EmaCore
import Swinit

/// This assume single window app
/// TODO: think about multi windows
///   swiftui way seem weird
public func runApp(size: Size<Float>, @ViewBuilder _ body: () -> Body) -> Runtime {
  let runtime = Runtime(size: size)
  Runtime.$current.withValue(runtime) {
    let rootNode = Runtime.current!.root
    rootNode.appendChildren(body().childNodes)
  }

  return runtime
}

// public func emaInit(appName: String) {
// }

// func usage() {
//   runApp {

//   }
// }