import AbeliaGraphics

func makeNodes() -> [RenderNode] {
    let center: SIMD3<Float> = [300, 300, 0]

    // 180° rotation puts the closed end at 12 o'clock (gap at bottom), matching Apple Health style

    // Outer ring — Move (red), 75%
    let moveProgress: Float = 0.75
    let moveBg = RenderNode(
        shape: Shape.arc(radius: 140, angle: .pi(2), thickness: 26),
        brush: .solid(Color(red: 0.5, green: 0.05, blue: 0.15, alpha: 0.4)),
        offset: center
    )
    let moveFg = RenderNode(
        shape: Shape.arc(radius: 140, angle: .radians(.pi * 2 * moveProgress), thickness: 26),
        brush: .solid(Color(red: 1, green: 0.1, blue: 0.3)),
        offset: center,
        rotation: .degrees(180)
    )

    // Middle ring — Exercise (green), 60%
    let exerciseProgress: Float = 0.60
    let exerciseBg = RenderNode(
        shape: Shape.arc(radius: 104, angle: .pi(2), thickness: 26),
        brush: .solid(Color(red: 0.05, green: 0.35, blue: 0.1, alpha: 0.4)),
        offset: center
    )
    let exerciseFg = RenderNode(
        shape: Shape.arc(radius: 104, angle: .radians(.pi * 2 * exerciseProgress), thickness: 26),
        brush: .solid(Color(red: 0.2, green: 1, blue: 0.35)),
        offset: center,
        rotation: .degrees(180)
    )

    // Inner ring — Stand (cyan), 90%
    let standProgress: Float = 0.90
    let standBg = RenderNode(
        shape: Shape.arc(radius: 68, angle: .pi(2), thickness: 26),
        brush: .solid(Color(red: 0.05, green: 0.25, blue: 0.45, alpha: 0.4)),
        offset: center
    )
    let standFg = RenderNode(
        shape: Shape.arc(radius: 68, angle: .radians(.pi * 2 * standProgress), thickness: 26),
        brush: .solid(Color(red: 0.4, green: 0.9, blue: 1)),
        offset: center,
        rotation: .degrees(180)
    )

    // backgrounds first so foreground arcs composite on top
    return [moveBg, exerciseBg, standBg, moveFg, exerciseFg, standFg]
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
    // renderer.viewAffine = Affine().rotated(.degrees(10), axis: [1, 0, 0])

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
