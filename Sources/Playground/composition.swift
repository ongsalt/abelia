import AbeliaGraphics
import Foundation
import Swinit

@MainActor
final class SpringCircleScene {
    let canvas: ShapeLayer
    private let compositor: Compositor
    private let primaryCircle: SpringAnimator<Vec2<Float>>

    private let primaryRadius: Float = 48
    private let secondaryRadius: Float = 48

    init(
        compositor: Compositor,
        controller: CompositorAnimationController,
        bounds: SIMD2<Float>
    ) {
        self.compositor = compositor
        self.canvas = ShapeLayer(size: bounds)

        self.primaryCircle = SpringAnimator(
            value: .zero,
            configuration: SpringConfiguration(response: 1, dampingRatio: 0.88),
            controller: controller
        )

        refreshShapes()
        compositor.requestAnimationFrame(callback: tick)
    }

    func updateBounds(_ bounds: SIMD2<Float>) {
        canvas.size = bounds
        refreshShapes()
    }

    func move(toward position: Vec2<Float>) {
        primaryCircle.value = clamp(position, within: canvas.size, radius: primaryRadius)
    }

    private func tick() {
        refreshShapes()
        compositor.requestAnimationFrame(callback: tick)
    }

    private func refreshShapes() {
        let c = canvas.size / 2
        let center = SIMD3(c.x, c.y, 0)
        canvas.shapes = [
            // ShapeItem(
            //     shape: Shape.rect(width: canvas.size.x, height: canvas.size.y),
            //     brush: .solid(.red.with(alpha: 0.1)),
            // ),
            ShapeItem(
                shape:
                    Shape
                    .circle(primaryRadius)
                    .union(
                        Shape.circle(secondaryRadius),
                        offset: primaryCircle.value.simd - c,
                        smoothing: 40
                    ),
                brush: .solid(.black),
                shadow: Shadow(),
                offset: center
            )
        ]
    }

    private func clamp(_ point: Vec2<Float>, within bounds: SIMD2<Float>, radius: Float) -> Vec2<
        Float
    > {
        guard bounds.x > radius * 2, bounds.y > radius * 2 else {
            return Vec2(bounds.x * 0.5, bounds.y * 0.5)
        }

        let x = min(max(point.x, radius), bounds.x - radius)
        let y = min(max(point.y, radius), bounds.y - radius)
        return Vec2(x, y)
    }
}

class Delegate: Swinit.EventLoopDelegate {
    var window: Window!
    var surfaceConfig: SurfaceConfiguration2!
    var context: GraphicsContext!
    var compositor: Compositor!
    var animationController: CompositorAnimationController!
    var springCircles: SpringCircleScene!

    func setupLayer(root: Layer) {
        root.size = [800, 600]
        root.brush = .solid(.white)

        // springCircles = SpringCircleScene(
        //     compositor: compositor,
        //     controller: animationController,
        //     bounds: root.size
        // )
        // root.insert(springCircles.canvas)


        let a = buildLayers()

        let b = OffscreenLayer(offset: [100, 0, 0], size: [100, 100]) {
            buildLayers()
        }
        b.opacity = 0.5
        b.rotation = .degrees(30)

        let c = buildLayers()
        c.offset = [0, 100, 0]
        c.opacity = 0.5
        c.rotation = .degrees(30)

        root.insert(a)
        root.insert(b)
        root.insert(c)

        root.insert(buildClipDemo())
        
        // root.insert(buildAnimationDemo(compositor))
        // root.insert(tiltCard.card)
    }

    func canCreateSurfaces(_ eventLoop: Swinit.EventLoop) {
        self.context = try! GraphicsContext(applicationName: "yomum", version: 12)
        let attr = WindowAttributes(
            title: "hihi",
            size: Size(width: 800, height: 600),
            noRedirectionBitmap: true,
        )

        self.window = eventLoop.openWindow(attr)
        #if os(Windows)
            window.backdropStyle = .acrylic
            window.drawUnderTitleBar = true
        #endif

        let surface = try! context.createSurface(window: window)

        let device = try! context.createDevice(compatibleWith: surface)
        surfaceConfig = SurfaceConfiguration2(
            width: window.size.width,
            height: window.size.height,
        )
        surface.configure(surfaceConfig)

        // compositor now own surface
        self.compositor = try! Compositor(surface: surface, device: device)

        self.animationController = CompositorAnimationController(compositor)
        self.compositor.root.size = SIMD2(Float(surfaceConfig.width), Float(surfaceConfig.height))

        setupLayer(root: self.compositor.root)
    }

    func windowEvent(_ eventLoop: EventLoop, window: Window, event: WindowEvent) {
        switch event {
        case .resized(let size, _):
            if let compositor {
                surfaceConfig.width = size.width
                surfaceConfig.height = size.height

                // make these happen on render thread
                compositor.root.size = SIMD2(Float(size.width), Float(size.height))
                compositor.configureSurface(surfaceConfig)
                // springCircles.updateBounds(compositor.root.size)
            }

        case .keyboardInput(_, let event, _) where event.state == .pressed:
            let x = Float.random(in: 0...compositor.root.size.x)
            let y = Float.random(in: 0...compositor.root.size.y)
            // springCircles.move(toward: Vec2(x, y))

        // case .cursorMoved(_, let p):
        //     springCircles.move(toward: Vec2(Float(p.x), Float(p.y)))

        case .closeRequested:
            compositor.stop {
                window.close()
                eventLoop.quit()
            }

        default:
            do {}
        }
    }

    func aboutToWait(_ eventLoop: EventLoop) {}
}

@MainActor
func buildLayersWithCompositionGroup(_ compositor: Compositor) -> Layer {
    let layer = Layer(brush: .solid(.white))

    let image = try! compositor.createImage(filename: "Resources/riko.png")
    let riko = Layer(offset: [300, -150, 0], size: [320 * 3, 180 * 3])
    riko.brush = .texture(image)
    riko.rotation = .degrees(30)
    layer.insert(riko)

    layer.insert(buildLayers())

    let child2 = buildLayers()
    // child2.border = Border(
    //     width: 1,
    //     brush: .solid(.red)
    // )
    // child2.shadow = Shadow()
    child2.opacity = 0.5
    child2.offset = [0, 120, 0]
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

// Demonstrates the SDF clip stack: nested clips intersect (rounded-rect ∩ circle), all evaluated
// directly in the fragment shader with no offscreen pass.
func buildClipDemo() -> Layer {
    // container clips its descendants to its own rounded rect (.bounds respects cornerRadius)
    let container = Layer(
        offset: [420, 40, 0], size: [240, 240], brush: .solid(.red.with(alpha: 0.12)),
        cornerRadius: 40)
    container.clip = .bounds

    // oversized child that overflows the container — cut to the rounded corners
    container.insert(Layer(offset: [-400, -400, 0], size: [1000, 1000], brush: .solid(.blue.with(alpha: 0.5))))

    // nested clip: its child is clipped to circle ∩ container-rounded-rect (the accumulated stack)
    let inner = Layer(offset: [60, 140, 0], size: [160, 160])
    inner.clip = .shape(Shape.circle(80))
    inner.insert(Layer(offset: [-30, -10, 0], size: [220, 220], brush: .solid(.orange)))
    container.insert(inner)

    return container
}

public func buildLayers() -> Layer {
    // EventLoop().run(Delegate())
    let layer = Layer(size: [100, 100])
    layer.insert {
        Layer(
            offset: [0, 0, 0],
            size: [50, 50],
            brush: .solid(.red),
            cornerRadius: 12,
            // shadow: Shadow(),
        )

        Layer(
            offset: [50, 0, 0],
            size: [50, 50],
            brush: .solid(.green),
            cornerRadius: 12,
            // shadow: Shadow(),
        )

        Layer(
            offset: [0, 50, 0],
            size: [50, 50],
            brush: .solid(.blue),
            cornerRadius: 12,
            // shadow: Shadow(),
        )

        Layer(
            offset: [50, 50, 0],
            size: [50, 50],
            brush: .solid(.yellow),
            cornerRadius: 12,
            // shadow: Shadow(),
        )
    }

    return layer
}

func buildHealthRings() -> Layer {
    let root = Layer(size: [800, 600])

    let center: SIMD3<Float> = [300, 140, 0]

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
        // the unioned circle is rotated + non-uniformly scaled into a tilted lobe
        shape: Shape.rect(width: 240, height: 240, cornerRadius: 80)
            .union(
                Shape.circle(100),
                offset: [100, 100], rotation: .degrees(35), scale: [1.6, 0.7],
                smoothing: 60
            ),
        brush: .solid(.blue),
        border: Border(width: 3, brush: .solid(.mint)),
        shadow: Shadow(blur: 30),
        offset: [600, 400, 0],
        rotation: .degrees(10),
        rotationAxis: [0.1, 1, 0]
    )

    // backgrounds first so foreground arcs composite on top
    let rings = ShapeLayer(shapes: [moveBg, exerciseBg, standBg, moveFg, exerciseFg, standFg, blob])
    root.insert(rings)
    return root
}

@MainActor
func buildAnimationDemo(_ compositor: Compositor) -> Layer {
    let root = Layer()
    root.size = [300, 300]
    let canvas = ShapeLayer()
    root.insert(canvas)

    let clock = ContinuousClock()
    let start = clock.now
    var lastFrame = clock.now
    var frameCount = 0
    var lastReport = clock.now

    func tick() {
        let now = clock.now
        let t = Float((now - start) / .seconds(1))
        let frameTime = (now - lastFrame) / .milliseconds(1)
        lastFrame = now
        frameCount += 1

        if now - lastReport >= .seconds(1) {
            let elapsed = (now - lastReport) / .seconds(1)
            let fps = Double(frameCount) / elapsed
            Log.info(
                .general,
                "fps: \(String(format: "%.1f", fps))  frame time: \(String(format: "%.2f", frameTime))ms"
            )
            frameCount = 0
            lastReport = now
        }

        let progress = Float(sin(t) * 0.5 + 0.5)
        canvas.shapes = [
            ShapeItem(
                shape: Shape.arc(radius: 120, angle: .radians(.pi * 2 * progress), thickness: 24),
                brush: .solid(.cyan),
                shadow: Shadow(),
                offset: [150, 150, 0],
                rotation: .radians(t),
            ),
            ShapeItem(
                shape: Shape.arc(
                    radius: 72, angle: .radians(.pi * 2 * (1 - progress)), thickness: 24),
                brush: .solid(.orange),
                offset: [150, 150, 0],
                rotation: .radians(-t * 1.3)
            ),
        ]
        compositor.requestAnimationFrame(callback: tick)
    }

    compositor.requestAnimationFrame(callback: tick)
    return root
}
