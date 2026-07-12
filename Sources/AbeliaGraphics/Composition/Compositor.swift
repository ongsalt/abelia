import Foundation
import Swinit
import Synchronization
import Vulkan

/// Flow
///  1. Main thread: hi there i want to render: lastRenderRequest mutex?
///  2. render thread: wait
///  3. render thread & main: pls run animation frame
///  4. render thread & main: produce pass
///  5. do its thing

@MainActor
public class Compositor {
    let frameNotifier: RenderNotifier
    private nonisolated(unsafe) let renderLoop: RenderLoop
    private nonisolated(unsafe) var renderer: Renderer

    // private var knownSurfaces: [Angle] = []
    // TODO: move compositionSurface out
    nonisolated(unsafe) private let surface: any Surface2
    public var root = Layer()

    private var scheduler = RenderScheduler()

    public init(surface: any Surface2, device: DeviceContext) throws {
        self.renderLoop = try RenderLoop(
            context: device, maxFrameInFlightCount: surface.frameLatency)
        self.renderer = try Renderer(context: device, frameInFlightCount: surface.frameLatency)
        self.surface = surface
        self.frameNotifier = RenderNotifier(preRenderFrameCount: surface.frameLatency)

        self.startRenderThread()
    }

    public func onDirty() {
        frameNotifier.request()
    }

    public func notifyReconfigure() {
        frameNotifier.shouldWait = false
        frameNotifier.request()
        // we should update fif 
        renderLoop.updateFrameInFlightCount(surface.frameLatency)
        renderer.updateFrameInFlightCount(surface.frameLatency)
    }

    public func createImage(filename: String) throws -> CompositionImage {
        let future = try renderer.textureRegistry.loadImage(filename: filename)
        return CompositionImage(future.value)
    }

    var animationFrameCallbacks: [() -> Void] = []
    public func requestAnimationFrame(callback: @escaping () -> Void) {
        animationFrameCallbacks.append(callback)
        frameNotifier.request()
    }

    func sync() -> Pass? {
        let callbacks = animationFrameCallbacks
        animationFrameCallbacks = []
        for cb in callbacks {
            cb()
        }

        // mark layers clean

        // generate pass
        let (time, pass) = measure {
            scheduler.schedule(root: root)
        }
        Log.verbose(.scheduler, "Completed batching in \((time / .milliseconds(1)))ms")
        return pass
    }

    var renderThread: Thread?
    private func startRenderThread() {
        self.renderThread = Thread { [self] in
            // block until dirty
            while frameNotifier.shouldRender() {
                do {
                    surface.wait()
                    // let frameContext
                    // this should be async -> so not block main thread
                    let surfaceTexture = try surface.acquire()

                    let pass = DispatchQueue.main.sync { self.sync() }

                    let commands: GPUCommands = GPUCommands { [self] commandBuffer in
                        guard let pass else {
                            Log.info(.scheduler, "No pass.")
                            return
                        }

                        // Log.info(.scheduler, pass.dumpTree())
                        do {
                            let output = try renderer.render(
                                pass,
                                in: commandBuffer
                            )

                            var src = RenderTextureState.undefined
                            var dst = RenderTextureState.transferTarget
                            let surfaceToCopyDest = ImageMemoryBarrier2(
                                srcStageMask: src.stageMask, srcAccessMask: src.accessMask,
                                dstStageMask: dst.stageMask, dstAccessMask: dst.accessMask,
                                oldLayout: src.layout, newLayout: dst.layout,
                                srcQueueFamilyIndex: 0,
                                dstQueueFamilyIndex: 0, image: surfaceTexture.image,
                                subresourceRange: subresourceRange
                            )

                            src = .renderTarget
                            dst = .transferSource
                            let outputToCopySource = ImageMemoryBarrier2(
                                srcStageMask: src.stageMask, srcAccessMask: src.accessMask,
                                dstStageMask: dst.stageMask, dstAccessMask: dst.accessMask,
                                oldLayout: src.layout, newLayout: dst.layout,
                                srcQueueFamilyIndex: 0,
                                dstQueueFamilyIndex: 0, image: output.image,
                                subresourceRange: subresourceRange
                            )
                            output.currentLayout = dst.layout

                            commandBuffer.pipelineBarrier2(
                                .init(imageMemoryBarriers: [surfaceToCopyDest, outputToCopySource]))

                            // blit
                            let subresource = ImageSubresourceLayers(
                                aspectMask: .color, mipLevel: 0,
                                baseArrayLayer: 0, layerCount: 1)
                            let destSize = VkOffset3D(
                                x: Int32(surfaceTexture.width),
                                y: Int32(surfaceTexture.height),
                                z: 1
                            )
                            var color = VkClearColorValue(float32: (0.0, 0.0, 0.0, 0.0))
                            commandBuffer.clearColorImage(
                                image: surfaceTexture.image, imageLayout: .transferDstOptimal,
                                color: &color,
                                ranges: [
                                    ImageSubresourceRange(
                                        aspectMask: .color, baseMipLevel: 0,
                                        levelCount: 1, baseArrayLayer: 0,
                                        layerCount: 1)
                                ])
                            commandBuffer.blitImage2(
                                BlitImageInfo2(
                                    srcImage: output.image,
                                    srcImageLayout: output.currentLayout,
                                    dstImage: surfaceTexture.image,
                                    dstImageLayout: .transferDstOptimal,
                                    regions: [
                                        ImageBlit2(
                                            srcSubresource: subresource,
                                            srcOffsets: (.zero, destSize),
                                            dstSubresource: subresource,
                                            dstOffsets: (.zero, destSize)
                                        )
                                    ],
                                    filter: .nearest
                                )
                            )

                            src = .transferTarget
                            let transitionToPresent = ImageMemoryBarrier2(
                                srcStageMask: src.stageMask, srcAccessMask: src.accessMask,
                                dstStageMask: .bottomOfPipe, dstAccessMask: .none,
                                oldLayout: src.layout, newLayout: surfaceTexture.finalLayout,
                                srcQueueFamilyIndex: 0,
                                dstQueueFamilyIndex: 0, image: surfaceTexture.image,
                                subresourceRange: subresourceRange

                            )
                            commandBuffer.pipelineBarrier2(
                                DependencyInfo(imageMemoryBarriers: [transitionToPresent])
                            )

                        } catch {
                            Log.error(.compositor, "render error: \(error)")
                        }
                    }

                    try renderLoop.submit(
                        commands: commands,
                        waiting: surfaceTexture.acquireWait,
                        signalling: surfaceTexture.renderFinishedSignal,
                        signallingFence: surfaceTexture.inFlightFence
                    )

                    if let ms = try renderLoop.getLatestAvailableFrameTime() {
                        Log.verbose(.compositor, "Finished frame in \(ms)ms: \(1000 / ms)fps")
                    }

                    try surfaceTexture.present()
                } catch {
                    Log.error(.compositor, "error: \(error)")
                }
            }
            Log.info(.compositor, "Render thread stopped")

            DispatchQueue.main.async {
                self.onStop?()
            }
        }

        renderThread?.start()
    }

    var onStop: (() -> Void)?
    public func stop(onStop: (() -> Void)? = nil) {
        self.frameNotifier.stop()
        self.onStop = onStop
    }
}

class RenderNotifier: @unchecked Sendable {
    let condition = NSCondition()
    let ignored: Bool
    var preRenderFrameCount: Int
    var hasRequested: Bool = false
    var shouldStop: Bool = false

    init(ignored: Bool = false, preRenderFrameCount: Int) {
        self.ignored = ignored
        self.preRenderFrameCount = preRenderFrameCount
    }

    func stop() {
        condition.withLock {
            shouldStop = true
            condition.signal()
        }
    }

    func request() {
        condition.withLock {
            hasRequested = true
            condition.signal()
        }
    }

    func shouldRender() -> Bool {
        condition.withLock {
            if shouldStop {
                return false
            }
            if ignored {
                return true
            }
            if preRenderFrameCount > 0 {
                preRenderFrameCount -= 1
                return true
            }
            if hasRequested {
                hasRequested = false
                return true
            }
            condition.wait()
            return !shouldStop
        }
    }

    private let _shouldWait = Mutex(true)
    var shouldWait: Bool {
        get {
            _shouldWait.withLock { $0 }
        }
        set {
            _shouldWait.withLock { $0 = newValue }
        }
    }
}
