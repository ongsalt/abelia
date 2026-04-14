import Composition
import Foundation
import UI

@Autobind
class CounterFr: Component {
    @State
    var count = 0

    var body: some View {
        Container {
            Text("count: \(self.count)")

            Button(onClick: { self.count += 1 }) {
                Text("increment")
            }
        }
    }
}

@MainActor
func Button(
    onClick: @escaping () -> Void = {},
    @ViewBuilder contents: () -> some View
) -> some View {

    return Container {
        contents()
    }
}
