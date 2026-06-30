import AbeliaGraphics
import Swinit

class Delegate: Swinit.EventLoopDelegate {
    var window: Window!
    var surface: Surface!
    var surfaceConfig: SurfaceConfiguration!
    var context: GraphicsContext!
    var compositor: Compositor!

    func canCreateSurfaces(_ eventLoop: Swinit.EventLoop) {
        self.context = try! GraphicsContext(applicationName: "yomum", version: 12)
        self.window = eventLoop.openWindow(
            .init(title: "hihi", size: Size(width: 800, height: 600))
        )

        #if os(Linux)
            surface = try! context.createWaylandSurface(
                display: window!.display.raw,
                surface: window!.surface.raw
            )
        #elseif os(Windows)
            surface = try! context.createWin32Surface(
                hinstance: window!.hInstance,
                hwnd: window!.handle
            )
        #endif

        let device = try! context.createDevice(compatibleWith: surface)
        surfaceConfig = device.vulkanSurfaceConfig(width: 800, height: 600)
        try! surface.configure(surfaceConfig)

        self.compositor = try! Compositor(surface: surface, device: device)
        self.compositor.root = buildLayers()

        window.requestRedraw()
    }

    func windowEvent(
        _ eventLoop: Swinit.EventLoop, window: Swinit.Window, event: SwinitCore.WindowEvent
    ) {
        switch event {
        case .resized(let size, let isFinal):
            surfaceConfig.width = size.width
            surfaceConfig.height = size.height
            try! surface.configure(surfaceConfig)
            do {
                compositor.root.size = SIMD2(Float(size.width), Float(size.height))
                try compositor.flushFrame()
            } catch {
                print(error)
            }
        // if isFinal {
        // }
        case .redrawRequested:
            try! compositor.flushFrame()

        case .closeRequested:
            window.close()
            eventLoop.quit()
        default:
            do {}
        }
    }

    func aboutToWait(_ eventLoop: EventLoop) {
        // window.requestRedraw()
    }

}

EventLoop().run(Delegate())
