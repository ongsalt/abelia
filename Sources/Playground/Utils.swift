import Composition

import Foundation

import Swinit

class Responder: Swinit.Responder {
    typealias EventLoop = Swinit.EventLoop
    var onResumed: ((Compositor) -> Void)?

    var window: Window? = nil

    func resumed(eventLoop: EventLoop) {
        window = eventLoop.createWindow(title: "Playground")

        #if os(Linux)
            // TODO: mova wl stuff out
            let vulkanState = VulkanState(
                waylandDisplay: display.display,
                waylandSurface: window.surface.surface
            )
        #endif

        #if os(Windows)
            let vulkanState = VulkanState(
                hinstance: window!.hInstance,
                hwnd: window!.handle
            )
        // window?.backdropStyle = .mica
        #endif  // canImport(SwinitWin32)

        DispatchQueue.main.async { [onResumed] in
            let compositor = Compositor(state: vulkanState)
        }
        // onResumed?(compositor)
    }

    func windowEvent(
        eventLoop: EventLoop, windowId: Swinit.WindowId, event: Swinit.WindowEvent
    ) {
        switch event {
        case .closeRequested:
            self.window = nil
            eventLoop.stop()

        default:
            print(event)
        }
    }
}

@MainActor
func withCompositor(_ block: @escaping (Compositor) -> Void) {
    let eventLoop = EventLoop()!
    let r = Responder()
    r.onResumed = block
    eventLoop.run(r)
}
