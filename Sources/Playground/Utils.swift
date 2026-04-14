import Composition
import Foundation
import Wayland

@MainActor
func setupCompositor() throws -> (Compositor, RunLoopObservationToken) {
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

    let compositor = Compositor(state: vulkanState)
    let task = compositor.start()

    return (compositor, token)
}

