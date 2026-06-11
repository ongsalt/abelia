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

    let node = RenderNode()
    node.offset = [20, 20]
    node.brush = .solid(.red)
    node.shape = Shape.rect(width: 40, height: 40, cornerRadius: 12)

    do {
        let renderer = try Renderer(context: context.surfaceContexts[0])
        renderer.updateNodes([node])
        try renderer.render()
    } catch {
        print(error)
    }

    // // confirm generic specialization
    // let merged = Shape.rect(width: 100, height: 100)
    //     .intersect(Shape.circle(23), offset: [0, 25])
    //     .union(Shape.circle(24), offset: [100, 0])
    //     .intersect(Shape.arc(radius: 50, angle: Float.pi, thickness: 12), offset: [100, 0])
    //     .xor(
    //         Shape.circle(26)
    //             .union(Shape.rect(width: 50, height: 100, cornerRadius: 12), offset: [100, 0])
    //             .subtract(Shape.circle(27), offset: [100, 0]),
    //         offset: [100, 0]
    //     )

    // for s in merged.drawInstructions {
    //     print(s)
    // }

    return { id, event in
        if case .closeRequested = event {
            window = nil
            eventLoop.stop()
        } else {
            // print(event)
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
