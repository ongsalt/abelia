import Abelia

runEventLoop { eventLoop in
    let context = try! GraphicsContext(applicationName: "yomum", version: 12)
    var window: _? = eventLoop.createWindow(attributes: .init(title: "hihi", size: [600, 600]))

    #if os(Linux)
        let surface = try! context.createWaylandSurface(
            display: window!.display.raw, surface: window!.surface.raw)
    #elseif os(Windows)
        let surface = try! context.createWin32Surface(
            hinstance: window!.hInstance, hwnd: window!.handle)
    #endif
    try! context.initDevice(compatibleWith: surface)

    do {
        let renderer = try Renderer(context: context.surfaceContexts[0])
        try renderer.render()
    } catch {
        print(error)
    }

    return { id, event in
        if case .closeRequested = event {
            window = nil
            eventLoop.stop()
        }
    }
}

class Leak<T> {
    let value: T
    init(_ value: T) {
        self.value = value
        Unmanaged.passRetained(self)
    }    

    deinit {
        print("wtf \(value)")
    }
}
