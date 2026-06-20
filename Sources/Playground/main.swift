import AbeliaGraphics
import Swinit

class App: Swinit.EventLoopDelegate {
    var nodes = makeNodes()

    var window: Window!
    var surface: Surface!
    var surfaceConfig: SurfaceConfiguration!
    var context: GraphicsContext!
    var renderer: Renderer!
    var renderLoop: RenderLoop!

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
            surface = try context.createWin32Surface(
                hinstance: window!.hInstance,
                hwnd: window!.handle
            )
        #endif

        let device = try! context.createDevice(compatibleWith: surface)
        surfaceConfig = device.vulkanSurfaceConfig(width: 800, height: 600)
        try! surface.configure(surfaceConfig)
        self.renderer = try! context.createRenderer(for: surface, device: device)
        self.renderLoop = try! RenderLoop(context: device)

        try! self.render()
    }

    func windowEvent(
        _ eventLoop: Swinit.EventLoop, window: Swinit.Window, event: SwinitCore.WindowEvent
    ) {
        switch event {
        case .resized(let size, let isFinal):
            if isFinal {
                // try frameScheduler.resize(w: size.width, h: size.height)
                surfaceConfig.width = size.width
                surfaceConfig.height = size.height
                try! surface.configure(surfaceConfig)
                try! render()
                // try renderer.draw(nodes)
            }

        case .closeRequested:
            window.close()
            eventLoop.quit()
        default:
            do {}
        // print(event)
        }

    }

    func render() throws {
        let res = try renderLoop.waitForAvailableFrameInFlight()
        let backBuffer = try! surface.acquireCurrentTexture(signalling: res.imageAvailableSemaphore)
        let commands = GPUCommands { [self] commandBuffer in
            backBuffer.prepareRender().apply(to: commandBuffer)
            let task = try! renderer.createDrawTask(
                to: backBuffer.texture.image,
                view: backBuffer.texture.view,
                frameIndex: res.index,
                size: SIMD2(surfaceConfig.width, surfaceConfig.height),
                nodes: nodes,
            )
            task.work.apply(to: commandBuffer)
            backBuffer.preparePresent().apply(to: commandBuffer)
        }

        try renderLoop.render(
            waiting: res.imageAvailableSemaphore,
            signalling: backBuffer.renderCompletedSemaphore,
            commands: commands
        )

        try! backBuffer.present()
    }

}

EventLoop().run(App())

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

// renderer.viewAffine = Affine().rotated(.degrees(10), axis: [1, 0, 0])
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
