import AbeliaGraphics

func makeNodes() -> [RenderNode] {
    let node = RenderNode(
        shape: Shape.circle(50),
        brush: .solid(.red),
        offset: [200, 0, 0]
    )

    let node2 = RenderNode(
        shape: Shape.rect(width: 300, height: 300, cornerRadius: 100)
            .union(Shape.circle(100), offset: [150, 80], smoothing: 40)
            .intersect(Shape.circle(200), offset: [100, 100], smoothing: 36),
        brush: .solid(.blue),
        offset: [-140, -100, 0]
    )

    // flipped on Y axis around its right edge
    let node3 = RenderNode(
        shape: Shape.rect(width: 100, height: 100, cornerRadius: 0),
        brush: .solid(.green),
        offset: [200, 150, -100],
        rotation: .degrees(-50),
        rotationAxis: [0, 1, 0],
        transformOrigin: [50, 0]
    )

    // pill rotated 45° in-plane, scaled non-uniformly, pivot at center-bottom
    let node4 = RenderNode(
        shape: Shape.rect(width: 40, height: 160, cornerRadius: 20),
        brush: .solid(Color(red: 1, green: 0.5, blue: 0)),
        offset: [-80, 120, 0],
        scale: [1.5, 0.8],
        rotation: .degrees(45),
        transformOrigin: [0, 80]
    )

    // ring subtracted from a wide rect, tilted in 3D
    let node5 = RenderNode(
        shape: Shape.rect(width: 200, height: 80, cornerRadius: 8)
            .subtract(Shape.circle(30), offset: [0, 0]),
        brush: .solid(Color(red: 0.6, green: 0.2, blue: 0.9)),
        offset: [0, -180, 0],
        rotation: .degrees(20),
        rotationAxis: [1, 0.4, 0],
        transformOrigin: [0, 40]
    )

    // semi-transparent overlay sitting in front of node2
    let node6 = RenderNode(
        shape: Shape.circle(120),
        brush: .solid(Color(red: 1, green: 1, blue: 1, alpha: 0.25)),
        offset: [-80, -80, 10]
    )

    return [node, node2, node3, node4, node5, node6]
}

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

    let nodes = makeNodes()

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
