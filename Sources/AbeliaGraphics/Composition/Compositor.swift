class Compositor {
    let root: Layer = Layer()

    let renderLoop: RenderLoop
    let renderer: Renderer
    let surface: Surface
    let context: DeviceContext

    var rendererFrameResources: [RendererFrameResource]

    public init(surface: Surface, device: DeviceContext) throws {
        self.surface = surface
        self.context = device

        self.renderLoop = try RenderLoop(context: device)
        self.renderer = try Renderer(context: device)
        self.rendererFrameResources = try renderer.createFrameResources(amount: RenderLoop.maxFrameInFlightCount)
    }

    func flushFrame() throws {
        let res = try renderLoop.waitForAvailableFrameInFlight()
        let frameResource = rendererFrameResources[res.index]
        // let frameContext

        // flush animation frame
        let backBuffer = try! surface.acquireCurrentTexture(signalling: res.imageAvailableSemaphore)
        let commands = GPUCommands { [self] commandBuffer in
            backBuffer.prepareRender().apply(to: commandBuffer)

            var scheduler = RenderScheduler()
            backBuffer.texture
            let plan = scheduler.schedule(root: root)
            // plan.apply(borrowing: Renderer, resource: frameResource)

            // let task = try! renderer.createDrawTask(
            //     to: backBuffer.texture.image,
            //     view: backBuffer.texture.view,
            //     frameIndex: res.index,
            //     size: SIMD2(surfaceConfig.width, surfaceConfig.height),
            //     nodes: nodes,
            // )
            // task.work.apply(to: commandBuffer)
            backBuffer.preparePresent().apply(to: commandBuffer)
        }

        try renderLoop.render(
            waiting: res.imageAvailableSemaphore,
            signalling: backBuffer.renderCompletedSemaphore,
            commands: commands
        )

        try! backBuffer.present()

    }

    // var dirtyLayers: [_BaseLayer] = []
    // var dirtyLayerIds: Set<ObjectIdentifier> = []

    // func markDirty(_ layer: _BaseLayer, accumulated: Bool = false) {
    //     let (inserted, _) = dirtyLayerIds.insert(layer.id)
    //     if inserted {
    //         dirtyLayers.append(layer)
    //     }

    //     if accumulated {
    //         for c in layer.children {
    //             markDirty(c, accumulated: true)
    //         }
    //     }

    //     // tell renderer we need rerender
    //     // renderer.markRerenderNeeded(shouldRecreateSwapchain: shouldRecreateSwapchain)
    // }

    // // once fif is available, this will be called
    // func flush() {
    //     // trigger relayout / animation frame or shit?

    //     // this must produce draw commands
    // }
}
