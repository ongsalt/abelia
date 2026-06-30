import Vulkan

// might need to seperate composition surface
public class Compositor {
    public var root: Layer = Layer()

    let renderLoop: RenderLoop
    var renderer: Renderer
    let surface: Surface
    let context: DeviceContext

    public init(surface: Surface, device: DeviceContext) throws {
        self.surface = surface
        self.context = device

        self.renderLoop = try RenderLoop(context: device)
        self.renderer = try Renderer(
            context: device, frameInFlightCount: RenderLoop.maxFrameInFlightCount)
    }

    public func flushFrame() throws {
        let res = try renderLoop.waitForAvailableFrameInFlight()
        // let frameContext

        // flush animation frame
        let backBuffer = try! surface.acquireCurrentTexture(signalling: res.imageAvailableSemaphore)
        let commands: GPUCommands = GPUCommands { [self] commandBuffer in
            backBuffer.prepareRender().apply(to: commandBuffer)

            var scheduler = RenderScheduler()
            if let pass = scheduler.schedule(root: root) {
                Log.debug(.scheduler, pass.dumpTree())
                do {
                    let texture = try renderer.render(
                        pass,
                        to: backBuffer.texture.image,
                        view: backBuffer.texture.view,
                        in: commandBuffer
                    )

                    let c = RenderTextureState.renderTarget
                    let transitionToPresent = ImageMemoryBarrier2(
                        srcStageMask: c.stageMask, srcAccessMask: c.accessMask,
                        dstStageMask: .bottomOfPipe, dstAccessMask: .none,
                        oldLayout: c.layout, newLayout: .presentSrcKHR, srcQueueFamilyIndex: 0,
                        dstQueueFamilyIndex: 0, image: backBuffer.texture.image,
                        subresourceRange: subresourceRange

                    )
                    commandBuffer.pipelineBarrier2(
                        .init(imageMemoryBarriers: [transitionToPresent]))

                } catch {
                    print("[compositor] flushFrame: error: \(error)")
                }
            }
        }

        try renderLoop.submit(
            commands: commands,
            waiting: res.imageAvailableSemaphore,
            signalling: backBuffer.renderCompletedSemaphore,
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
