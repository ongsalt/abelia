import Foundation
import UI

@Autobind
class Counter: Component {
    @State
    var count = 0

    var body: some View {
        Text("count: \(self.count)")
    }

    init() {
        Task { [self] in
            while true {
                try await Task.sleep(for: .seconds(1))
                self.count += 1
            }
        }
    }
}

@Autobind
struct App: Component {
    var body: some View {
        // Text("sdfnhudki")
        Counter()
    }
}

let app = App()
app.body


RunLoop.main.run()