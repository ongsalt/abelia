// import Swinit

@MainActor
public func devEntry() {
    // EventLoop().run(Delegate())
    let layer = nonOverlapBlurGrid(w: 2, h: 2)
    layer.label = "RootFr"
    layer.insert(Layer(offset: [5, 5, 0], size: [10, 10]))
    // transparent subtree
    let subtree = Layer(offset: [5, 5, 0], size: [10, 10], opacity: 0.5) {
        Layer(offset: [1, 1, 1], size: [10, 10])
        Layer(offset: [2, 2, 2], size: [100, 100])
    }
    subtree.label = "subtree"
    layer.insert(subtree)

    layer.insert {
        EffectLayer(
            offset: [12, 12, 0],
            shape: Shape.rect(width: 3, height: 3),
            effect: .refraction(amount: 10, height: 10)
        )
    }

    var scheduler = RenderScheduler()
    let pass = scheduler.schedule(root: layer)

    print(pass.dumpTree())
}

extension Pass {
    public func dumpTree(indent: Int = 0) -> String {
        let prefix = String(repeating: "  ", count: indent)
        var info = "\(type(of: self)) "

        let k =
            switch kind {
            case .blur(let regions): "blur (\(regions.count))"
            case .composite(let nodes, _): "composite (\(nodes.count))"
            case .effect(let regions): "effect (\(regions.count))"
            }

        info += "kind=\(k) target=\(target)"
        var result = "\(prefix)- \(info)\n"

        for child in self.dependencies {
            result += child.dumpTree(indent: indent + 1)
        }
        return result
    }

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

// class Delegate: Swinit.EventLoopDelegate {
//     var window: Window!
//     var surface: Surface!
//     var surfaceConfig: SurfaceConfiguration!
//     var context: GraphicsContext!
//     var renderer: Renderer!
//     var renderLoop: RenderLoop!

//     func canCreateSurfaces(_ eventLoop: Swinit.EventLoop) {
//         self.context = try! GraphicsContext(applicationName: "yomum", version: 12)
//         self.window = eventLoop.openWindow(
//             .init(title: "hihi", size: Size(width: 800, height: 600))
//         )

//         #if os(Linux)
//             surface = try! context.createWaylandSurface(
//                 display: window!.display.raw,
//                 surface: window!.surface.raw
//             )
//         #elseif os(Windows)
//             surface = try! context.createWin32Surface(
//                 hinstance: window!.hInstance,
//                 hwnd: window!.handle
//             )
//         #endif

//         let device = try! context.createDevice(compatibleWith: surface)
//         surfaceConfig = device.vulkanSurfaceConfig(width: 800, height: 600)
//         try! surface.configure(surfaceConfig)
//         self.renderer = try! context.createRenderer(for: surface, device: device)
//         self.renderLoop = try! RenderLoop(context: device)

//         window.requestRedraw()
//     }

//     func windowEvent(
//         _ eventLoop: Swinit.EventLoop, window: Swinit.Window, event: SwinitCore.WindowEvent
//     ) {
//         switch event {
//         case .resized(let size, let isFinal):
//             surfaceConfig.width = size.width
//             surfaceConfig.height = size.height
//             try! surface.configure(surfaceConfig)
//         // if isFinal {
//         // }
//         case .redrawRequested:
//             try! render()

//         case .closeRequested:
//             window.close()
//             eventLoop.quit()
//         default:
//             do {}
//         }
//     }

//     func aboutToWait(_ eventLoop: EventLoop) {
//         window.requestRedraw()
//     }

//     func render() throws {
//         // this should not block main thread
//         let res = try renderLoop.waitForAvailableFrameInFlight()
//         let backBuffer = try! surface.acquireCurrentTexture(signalling: res.imageAvailableSemaphore)
//         let commands = GPUCommands { [self] commandBuffer in
//             // backBuffer.prepareRender().apply(to: commandBuffer)
//             // let task = try! renderer.createDrawTask(
//             //     to: backBuffer.texture.image,
//             //     view: backBuffer.texture.view,
//             //     frameIndex: res.index,
//             //     size: SIMD2(surfaceConfig.width, surfaceConfig.height),
//             //     nodes: nodes,
//             // )
//             // task.work.apply(to: commandBuffer)
//             // backBuffer.preparePresent().apply(to: commandBuffer)
//         }

//         try renderLoop.render(
//             waiting: res.imageAvailableSemaphore,
//             signalling: backBuffer.renderCompletedSemaphore,
//             commands: commands
//         )

//         try! backBuffer.present()
//     }

// }
