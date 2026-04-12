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

        // TODO: mova wl stuff out
        let vulkanState = VulkanState(
            waylandDisplay: display.display,
            waylandSurface: window.surface.surface
        )

        let renderer = Compositor(state: vulkanState)

        let rect = CompositionNode()
        rect.size = [100, 100]
        rect.fillColor = .red
        renderer.root.children.append(rect)

        Task {
            await renderer.recomposite()
        }
        // Task {
        //     let renderer = await Renderer2(state: vulkanState)
        //     await renderer.perform()

        //     _ = Unmanaged.passRetained(renderer)  // for now
        // }

        RunLoop.main.run()
        drop(token)
    }
}
