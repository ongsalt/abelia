import Abelia

runEventLoop { eventLoop in
    let context = try GraphicsContext(applicationName: "yomum", version: 12)
    var window: _? = eventLoop.createWindow(attributes: .init(title: "hihi", size: [600, 600]))

    #if os(Linux)
        let surface = try context.createWaylandSurface(
            display: window!.display.raw, surface: window!.surface.raw)
    #elseif os(Windows)
        let surface = try context.createWin32Surface(
            hinstance: window!.hInstance, hwnd: window!.handle)
    #endif
    try context.initDevice(compatibleWith: surface)

    let node = RenderNode()
    node.offset = [200, 20]
    node.brush = .solid(.red)
    node.shape = Shape.rect(width: 40, height: 40, cornerRadius: 12)
    let nodes = [node]

    let renderer = try Renderer(context: context.surfaceContexts[0])
    renderer.updateNodes(nodes)
    try renderer.render(nodeCount: UInt32(nodes.count))

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
        switch event {
        case .resized(let size, let isFinal):
            // if isFinal {
                try renderer.resize(w: size.width, h: size.height)
                renderer.updateNodes(nodes)
                try renderer.render(nodeCount: UInt32(nodes.count))
            // }

        case .closeRequested:
            window = nil
            eventLoop.stop()
        default:
            do {}
        // print(event)
        }
    }
}
