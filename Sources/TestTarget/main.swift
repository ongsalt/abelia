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
    node.offset = [200, 0]
    node.brush = .solid(.red)
    node.shape = Shape.rect(width: 100, height: 100, cornerRadius: 36)

    let node2 = RenderNode()
    node2.offset = [-100, -100]
    node2.shape = Shape.rect(width: 100, height: 100, cornerRadius: 0)
        .union(Shape.circle(50), offset: [-60, 30], smoothing: 15)
    node2.brush = .solid(.blue)

    let node3 = RenderNode()
    node3.offset = [200, 120]
    node3.brush = .solid(.green)
    node3.shape = Shape.rect(width: 100, height: 100, cornerRadius: 0)

    let nodes = [node, node2, node3]

    let renderer = try Renderer(context: context.surfaceContexts[0])
    renderer.updateNodes(nodes)
    try renderer.render(nodeCount: UInt32(nodes.count))

    // Task {
    //     while !Task.isCancelled {
    //         // this is ass, the render thread should actually poll us
    //         try await Task.sleep(for: .milliseconds(16))
    //         nodes[0].offset.x += 2
    //         renderer.updateNodes(nodes)
    //         try renderer.render(nodeCount: UInt32(nodes.count))
    //     }
    // }

    return { id, event in
        switch event {
        case .resized(let size, let isFinal):
            if isFinal {
                try renderer.resize(w: size.width, h: size.height)
                renderer.updateNodes(nodes)
                try renderer.render(nodeCount: UInt32(nodes.count))
            }

        case .closeRequested:
            window = nil
            eventLoop.stop()
        default:
            do {}
        // print(event)
        }
    }
}
