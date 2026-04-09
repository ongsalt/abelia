import Foundation

@main
struct Main {
    public static func main() {
        let count = Signal(0)

        Graph {
            Effect {
                print("count = \(count.value)")
                Effect {
                    print("[inner] count = \(count.value)")
                }
            }
        }

        Task {
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(1))
                count.value += 1
            }
        }

        RunLoop.main.run()
    }
}
