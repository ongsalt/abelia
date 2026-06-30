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
        // let layer = buildLayers()
        // let grid = nonOverlapBlurGrid(w: 10, h: 10)
        // layer.insert(grid)

        self.compositor.root = buildLayersWithCompositionGroup(compositor)
        // self.compositor.root = buildHealthRings()

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
                try! compositor.flushFrame()
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

func buildLayersWithCompositionGroup(_ compositor: Compositor) -> Layer {
    let layer = Layer(brush: .solid(.white))

    let image = try! compositor.createImage(filename: "Resources/riko.png")
    let riko = Layer(offset: [100, 120, 0], size: [320, 180])
    riko.brush = .texture(image)
    layer.insert(riko)

    layer.insert(buildLayers())

    let child2 = buildLayers()
    // child2.border = Border(
    //     width: 1,
    //     brush: .solid(.red)
    // )
    // child2.shadow = Shadow()
    child2.opacity = 0.5
    child2.offset = [100, 100, 0]
    layer.insert(child2)

    layer.insert(buildHealthRings())

    let g = gammaTest()
    g.offset = [0, 200, 0]
    layer.insert(g)

    return layer
}

func gammaTest() -> Layer {
    let container = Layer()

    func makeBar(_ color: Color, y: Float) {
        container.insert {
            Layer(offset: [0, y, 0], size: [600, 25], brush: .solid(color))
            Layer(offset: [0, y + 25, 0], size: [600, 25], brush: .solid(color.with(alpha: 0.5)))
        }
    }

    func makeBg(_ color: Color, x: Float) {
        container.insert {
            Layer(offset: [x, 80, 0], size: [80, 400], brush: .solid(color))
        }
    }

    makeBg(.green, x: 100)
    makeBg(.yellow, x: 200)
    makeBg(.cyan, x: 300)
    makeBg(.pink, x: 400)

    makeBar(Color(red: 1.0, green: 0.0, blue: 0.0), y: 100)
    makeBar(Color(red: 0.0, green: 1.0, blue: 0.0), y: 200)
    makeBar(Color(red: 0.0, green: 0.0, blue: 1.0), y: 300)

    return container
}

public func buildLayers() -> Layer {
    // EventLoop().run(Delegate())
    let layer = Layer(size: [100, 100], brush: .solid(.purple))
    layer.insert {
        Layer(
            offset: [0, 0, 0],
            size: [50, 50],
            brush: .solid(.blue),
            cornerRadius: 12,
            // shadow: Shadow(),
        )

        Layer(
            offset: [50, 0, 0],
            size: [50, 50],
            brush: .solid(.cyan),
            cornerRadius: 12,
            // shadow: Shadow(),
        )

        Layer(
            offset: [0, 50, 0],
            size: [50, 50],
            brush: .solid(.teal),
            cornerRadius: 12,
            // shadow: Shadow(),
        )

        Layer(
            offset: [50, 50, 0],
            size: [50, 50],
            brush: .solid(.green),
            cornerRadius: 12,
            // shadow: Shadow(),
        )
    }

    return layer
}

func buildHealthRings() -> Layer {
    let root = Layer(size: [800, 600])

    let center: SIMD3<Float> = [400, 300, 0]

    let moveProgress: Float = 0.75
    let moveBg = ShapeItem(
        shape: Shape.arc(radius: 140, angle: .pi(2), thickness: 26),
        brush: .solid(Color.red.with(alpha: 0.3)),
        offset: center
    )
    let moveFg = ShapeItem(
        shape: Shape.arc(radius: 140, angle: .radians(.pi * 2 * moveProgress), thickness: 26),
        brush: .solid(.red),
        offset: center,
        rotation: .degrees(180)
    )

    let exerciseProgress: Float = 0.60
    let exerciseBg = ShapeItem(
        shape: Shape.arc(radius: 104, angle: .pi(2), thickness: 26),
        brush: .solid(.green.with(alpha: 0.3)),
        offset: center
    )
    let exerciseFg = ShapeItem(
        shape: Shape.arc(radius: 104, angle: .radians(.pi * 2 * exerciseProgress), thickness: 26),
        brush: .solid(.green),
        offset: center,
        rotation: .degrees(180)
    )

    let standProgress: Float = 0.90
    let standBg = ShapeItem(
        shape: Shape.arc(radius: 68, angle: .pi(2), thickness: 26),
        brush: .solid(.cyan.with(alpha: 0.3)),
        offset: center
    )
    let standFg = ShapeItem(
        shape: Shape.arc(radius: 68, angle: .radians(.pi * 2 * standProgress), thickness: 26),
        brush: .solid(.cyan),
        offset: center,
        rotation: .degrees(180)
    )

    let blob = ShapeItem(
        shape: Shape.rect(width: 240, height: 240, cornerRadius: 80)
            .union(Shape.circle(100), offset: [100, 100], smoothing: 60),
        brush: .solid(.blue.with(alpha: 0.75)),
        border: Border(width: 12, brush: .solid(.mint)),
        offset: [600, 400, 0],
        rotation: .degrees(10),
        rotationAxis: [0.1, 1, 0]
    )

    // backgrounds first so foreground arcs composite on top
    let rings = ShapeLayer(shapes: [moveBg, exerciseBg, standBg, moveFg, exerciseFg, standFg, blob])
    root.insert(rings)
    return root
}

func nonOverlapBlurGrid(w: Int, h: Int, size: Float = 10) -> Layer {
    let root = Layer(size: SIMD2(Float(w) * size, Float(h) * size))
    for x in 0..<w {
        for y in 0..<h {
            root.insert(
                EffectLayer(
                    offset: SIMD3(Float(x) * size, Float(y) * size, 0),
                    shape: Shape.rect(width: size, height: size, cornerRadius: 10),
                    effect: .blur(radius: 20)
                )
            )
        }
    }

    return root
}
