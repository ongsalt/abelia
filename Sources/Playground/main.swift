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
    let layer = Layer(size: [500, 500])

    let image = try! compositor.createImage(filename: "Resources/riko.png")
    let riko = Layer(offset: [150, 150, 0], size: [320, 180])
    riko.brush = .texture(image)
    layer.insert(riko)

    layer.insert(buildLayers())

    let child2 = buildLayers()
    // child2.border = Border(
    //     width: 1,
    //     brush: .solid(.red)
    // )
    // child2.shadow = Shadow()
    child2.opacity = 0.75
    child2.offset = [220, 0, 0]
    layer.insert(child2)

    return layer
}

public func buildLayers() -> Layer {
    // EventLoop().run(Delegate())
    let layer = Layer(size: [200, 200], brush: .solid(.purple), )
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
            shadow: Shadow(),
        )

        Layer(
            offset: [50, 50, 0],
            size: [50, 50],
            brush: .solid(.green),
            cornerRadius: 12,
            // shadow: Shadow(),
        )
    }
    // let layer = nonOverlapBlurGrid(w: 2, h: 2)
    // layer.label = "RootFr"
    // layer.insert(Layer(offset: [5, 5, 0], size: [10, 10]))
    // // transparent subtree
    // let subtree = Layer(offset: [5, 5, 0], size: [10, 10], opacity: 0.5, brush: .solid(.red)) {
    //     Layer(offset: [1, 1, 1], size: [10, 10], brush: .solid(.green))
    //     Layer(offset: [2, 2, 2], size: [100, 100], brush: .solid(.blue))
    // }
    // subtree.label = "subtree"
    // layer.insert(subtree)

    // layer.insert {
    //     EffectLayer(
    //         offset: [12, 12, 0],
    //         shape: Shape.rect(width: 3, height: 3),
    //         effect: .refraction(amount: 10, height: 10)
    //     )
    // }

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
