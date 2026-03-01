@preconcurrency import CVMA
import CoreFoundation
import Foundation
import Synchronization
import Wayland

@main
@MainActor
struct Graphics101 {
    static func main() throws {
        let instance = Graphics101()
        try instance.run()
    }

    func run() throws {
        let display = try Display()
        display.monitorEvents()

        let window: RawWindow = RawWindow(display: display, title: "yomama")
        window.show()

        let token = RunLoop.main.addListener(on: [.beforeWaiting]) { _ in
            // print("Will sleep")
            display.dispatchPending()
            display.flush()
        }

        let vulkanState = VulkanState(
            waylandDisplay: display.display,
            waylandSurface: window.surface.surface
        )

        let renderer = Renderer2(state: vulkanState)
        Task {
            await renderer.perform()
        }

        RunLoop.main.run()
        drop(token)
    }
}
