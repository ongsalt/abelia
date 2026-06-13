import AbeliaGraphics

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
    node.offset = [200, 0, 0]
    node.brush = .solid(.red)
    node.shape = Shape.circle(50)

    let node2 = RenderNode()
    node2.offset = [-140, -100, 0]
    node2.shape = Shape.rect(width: 300, height: 300, cornerRadius: 100)
        .union(Shape.circle(100), offset: [150, 80], smoothing: 40)
        .intersect(Shape.circle(200), offset: [100, 100], smoothing: 36)
    node2.brush = .solid(.blue)

    let node3 = RenderNode()
    node3.offset = [200, 150, -100]
    node3.brush = .solid(.green)
    node3.shape = Shape.rect(width: 100, height: 100, cornerRadius: 0)
    node3.affine = Affine().rotated(.degrees(-50), axis: [0, 1, 0])

    let nodes = [node, node2, node3]

    let (renderer, frameScheduler) = try context.createRenderer()
    renderer.viewAffine = Affine().rotated(.degrees(10), axis: [1, 0, 0])

    func render() throws {
        try frameScheduler.render { image, imageView, commandBuffer, frameIndex, size in
            let task = try! renderer.createDrawTask(
                to: image,
                view: imageView,
                frameIndex: frameIndex,
                size: size,
                nodes: nodes,
            )

            task.work.apply(to: commandBuffer)
        }
    }

    try render()

    // try renderer.draw(nodes)
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
            // if isFinal {
                // try frameScheduler.resize(w: size.width, h: size.height)
                try frameScheduler.reconfigure()
                try render()
                // try renderer.draw(nodes)
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
