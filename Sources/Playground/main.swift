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
    let layer = Layer(size: [500, 500], brush: .solid(.mint))

    let image = try! compositor.createImage(filename: "Resources/riko.png")
    let riko = Layer(offset: [100, 300, 0], size: [320, 180])
    riko.brush = .texture(image)
    layer.insert(riko)

    layer.insert(buildLayers())

    let r2 = buildLayers()
    r2.offset = [100, 100, 0]
    layer.insert(r2)

    let child2 = buildLayers()
    // child2.border = Border(
    //     width: 1,
    //     brush: .solid(.red)
    // )
    // child2.shadow = Shadow()
    child2.opacity = 0.75
    child2.offset = [100, 100, 0]
    layer.insert(child2)

    return layer
}

public func buildLayers() -> Layer {
    // EventLoop().run(Delegate())
    let layer = Layer(size: [100, 100], brush: .solid(.purple), )
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
